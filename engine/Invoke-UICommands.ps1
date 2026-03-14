function Invoke-UICommands {
    param([string[]]$Commands)
    foreach ($cmd in $Commands) {
        if (-not $cmd -or $cmd.StartsWith('#')) { continue }

        $tokens = $cmd -split ' '
        $verb   = $tokens[0]
        $target = if ($tokens.Count -gt 1) { $tokens[1] } else { $null }
        $rest   = if ($tokens.Count -gt 2) { ($tokens[2..($tokens.Count-1)]) -join ' ' } else { $null }

        switch ($verb) {
            'set' {
                $dot   = $target.IndexOf('.')
                $ctrl  = $target.Substring(0, $dot)
                $prop  = $target.Substring($dot + 1)
                $value = $rest

                foreach ($name in (Resolve-Targets $ctrl)) {
                    $control = $script:EntityRegistry[$name].Control
                    if (-not $control) { $control = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if (-not $control) { Write-Warning "UI: unknown control '$name'"; continue }

                    $propInfo = $control.GetType().GetProperty($prop)
                    if ($propInfo) {
                        $propType = $propInfo.PropertyType
                        $underlying = [System.Nullable]::GetUnderlyingType($propType)
                        if ($underlying) { $propType = $underlying }

                        $typedValue = switch ($propType.Name) {
                            'Boolean' { $value -eq 'true' }
                            'Int32'   { [int]$value }
                            'Double'  { [double]$value }
                            'Brush'   { [System.Windows.Media.BrushConverter]::new().ConvertFromString($value) }
                            default   { $value }
                        }
                        $propInfo.SetValue($control, $typedValue)
                    } else {
                        $control.$prop = $value
                    }
                }
            }
            'setb64' {
                $dot   = $target.IndexOf('.')
                $ctrl  = $target.Substring(0, $dot)
                $prop  = $target.Substring($dot + 1)
                $value = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($rest))

                foreach ($name in (Resolve-Targets $ctrl)) {
                    $control = $script:EntityRegistry[$name].Control
                    if (-not $control) { $control = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if (-not $control) { Write-Warning "UI: unknown control '$name'"; continue }

                    $propInfo = $control.GetType().GetProperty($prop)
                    if ($propInfo) {
                        $propType = $propInfo.PropertyType
                        $underlying = [System.Nullable]::GetUnderlyingType($propType)
                        if ($underlying) { $propType = $underlying }

                        $typedValue = switch ($propType.Name) {
                            'Boolean' { $value -eq 'true' }
                            'Int32'   { [int]$value }
                            'Double'  { [double]$value }
                            'Brush'   { [System.Windows.Media.BrushConverter]::new().ConvertFromString($value) }
                            default   { $value }
                        }
                        $propInfo.SetValue($control, $typedValue)
                    } else {
                        $control.$prop = $value
                    }
                }
            }
            'show' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.Visibility = 'Visible' } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'hide' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.Visibility = 'Collapsed' } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'enable' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.IsEnabled = $true } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'disable' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.IsEnabled = $false } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'add' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.Items.Add($rest) | Out-Null } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'remove' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.Items.RemoveAt([int]$rest) } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'clear' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.Items.Clear() } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'select' {
                foreach ($name in (Resolve-Targets $target)) {
                    $c = $script:EntityRegistry[$name].Control
                    if (-not $c) { $c = Get-Variable $name -ValueOnly -ErrorAction SilentlyContinue }
                    if ($c) { $c.SelectedIndex = [int]$rest } else { Write-Warning "UI: unknown control '$name'" }
                }
            }
            'tag' {
                Add-Tag -EntityName $target -TagName $rest
            }
            'untag' {
                Remove-Tag -EntityName $target -TagName $rest
            }
            'spawn' {
                if ($target.StartsWith('@')) {
                    # Archetype spawn: spawn @archetype entityName parentName
                    $archetypeName = $target.Substring(1)
                    $entityName = $rest -split ' ' | Select-Object -First 1
                    $parentName = ($rest -split ' ' | Select-Object -Skip 1) -join ' '

                    # Idempotent: skip if already exists
                    if ($script:EntityRegistry.ContainsKey($entityName)) { continue }

                    if (-not $script:Archetypes.ContainsKey($archetypeName)) {
                        Write-Warning "UI: unknown archetype '$archetypeName'"
                        continue
                    }

                    $parentCtrl = $null
                    if ($script:EntityRegistry.ContainsKey($parentName)) {
                        $parentCtrl = $script:EntityRegistry[$parentName].Control
                    }
                    if (-not $parentCtrl) { $parentCtrl = Get-Variable $parentName -ValueOnly -ErrorAction SilentlyContinue }
                    if (-not $parentCtrl) { Write-Warning "UI: unknown parent '$parentName'"; continue }

                    # Create container StackPanel
                    $container = New-Object System.Windows.Controls.StackPanel
                    $parentCtrl.Children.Add($container) | Out-Null
                    Register-Entity -Name $entityName -Control $container -ParentName $parentName

                    # Track type counts for duplicate naming
                    $typeCounts = @{}
                    $typeList = $script:Archetypes[$archetypeName]
                    foreach ($t in $typeList) {
                        if (-not $typeCounts.ContainsKey($t)) { $typeCounts[$t] = 0 }
                        $typeCounts[$t]++
                    }

                    # Determine which types need indexing
                    $needsIndex = @{}
                    foreach ($t in $typeCounts.Keys) {
                        $needsIndex[$t] = ($typeCounts[$t] -gt 1)
                    }

                    $currentIndex = @{}
                    foreach ($typeName in $typeList) {
                        $fullType = "System.Windows.Controls.$typeName"
                        $child = New-Object $fullType

                        $abbrev = if ($script:TypeAbbrev.ContainsKey($typeName)) { $script:TypeAbbrev[$typeName] } else { $typeName.ToLower() }

                        if ($needsIndex[$typeName]) {
                            if (-not $currentIndex.ContainsKey($typeName)) { $currentIndex[$typeName] = 0 }
                            $currentIndex[$typeName]++
                            $childName = "${entityName}_${abbrev}$($currentIndex[$typeName])"
                        } else {
                            $childName = "${entityName}_${abbrev}"
                        }

                        $container.Children.Add($child) | Out-Null
                        Register-Entity -Name $childName -Control $child -ParentName $entityName
                        Add-Tag -EntityName $childName -TagName $entityName
                    }
                } else {
                    # Single spawn: spawn Type name parent
                    $typeName = $target
                    $spawnTokens = $rest -split ' '
                    $entityName = $spawnTokens[0]
                    $parentName = if ($spawnTokens.Count -gt 1) { ($spawnTokens[1..($spawnTokens.Count-1)]) -join ' ' } else { $null }

                    # Idempotent: skip if already exists
                    if ($script:EntityRegistry.ContainsKey($entityName)) { continue }

                    $fullType = "System.Windows.Controls.$typeName"
                    $ctrl = New-Object $fullType

                    $parentCtrl = $null
                    if ($parentName -and $script:EntityRegistry.ContainsKey($parentName)) {
                        $parentCtrl = $script:EntityRegistry[$parentName].Control
                    }
                    if (-not $parentCtrl -and $parentName) { $parentCtrl = Get-Variable $parentName -ValueOnly -ErrorAction SilentlyContinue }

                    if ($parentCtrl) {
                        $parentCtrl.Children.Add($ctrl) | Out-Null
                    }

                    Register-Entity -Name $entityName -Control $ctrl -ParentName $parentName
                }
            }
            'destroy' {
                Unregister-Entity $target
            }
            'archetype' {
                # archetype name Type1 Type2 ...
                $types = $rest -split ' '
                $script:Archetypes[$target] = $types
            }
            default {
                Write-Warning "UI: unknown command '$verb'"
            }
        }
    }
}
