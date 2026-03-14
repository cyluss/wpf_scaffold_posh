# Entity Component System — registry, tag index, archetypes, helpers

$script:EntityRegistry = @{}
$script:TagIndex = @{}
$script:Archetypes = @{}

$script:TypeAbbrev = @{
    TextBox    = 'tbx'; TextBlock  = 'tbl'; Label      = 'lbl'
    Button     = 'btn'; CheckBox   = 'chk'; ComboBox   = 'cmb'
    StackPanel = 'stk'; WrapPanel  = 'wrp'; Grid       = 'grd'
}

function Register-Entity {
    param([string]$Name, $Control, [string]$ParentName)
    $script:EntityRegistry[$Name] = @{
        Control = $Control
        Tags    = [System.Collections.Generic.List[string]]::new()
        Parent  = $ParentName
    }
    Set-Variable -Name $Name -Value $Control -Scope Script
}

function Unregister-Entity {
    param([string]$Name)
    $entry = $script:EntityRegistry[$Name]
    if (-not $entry) { return }

    # Remove from all tag indexes
    foreach ($tag in @($entry.Tags)) {
        if ($script:TagIndex.ContainsKey($tag)) {
            $script:TagIndex[$tag].Remove($Name)
            if ($script:TagIndex[$tag].Count -eq 0) {
                $script:TagIndex.Remove($tag)
            }
        }
    }

    # Recursively destroy children
    $children = @($script:EntityRegistry.Keys | Where-Object {
        $script:EntityRegistry[$_].Parent -eq $Name
    })
    foreach ($child in $children) {
        Unregister-Entity $child
    }

    # Remove from parent's Children collection
    if ($entry.Parent -and $script:EntityRegistry.ContainsKey($entry.Parent)) {
        $parentCtrl = $script:EntityRegistry[$entry.Parent].Control
        if ($parentCtrl.Children) {
            $parentCtrl.Children.Remove($entry.Control) | Out-Null
        }
    }

    $script:EntityRegistry.Remove($Name)
    Remove-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
}

function Resolve-Targets {
    param([string]$Target)
    if ($Target.StartsWith('@')) {
        $group = $Target.Substring(1)
        if ($script:TagIndex.ContainsKey($group)) {
            return @($script:TagIndex[$group])
        }
        return @()
    }
    return @($Target)
}

function Add-Tag {
    param([string]$EntityName, [string]$TagName)
    if (-not $script:EntityRegistry.ContainsKey($EntityName)) { return }
    $entry = $script:EntityRegistry[$EntityName]
    if ($entry.Tags -notcontains $TagName) {
        $entry.Tags.Add($TagName)
    }
    if (-not $script:TagIndex.ContainsKey($TagName)) {
        $script:TagIndex[$TagName] = [System.Collections.Generic.List[string]]::new()
    }
    if ($script:TagIndex[$TagName] -notcontains $EntityName) {
        $script:TagIndex[$TagName].Add($EntityName)
    }
}

function Remove-Tag {
    param([string]$EntityName, [string]$TagName)
    if (-not $script:EntityRegistry.ContainsKey($EntityName)) { return }
    $script:EntityRegistry[$EntityName].Tags.Remove($TagName) | Out-Null
    if ($script:TagIndex.ContainsKey($TagName)) {
        $script:TagIndex[$TagName].Remove($EntityName) | Out-Null
        if ($script:TagIndex[$TagName].Count -eq 0) {
            $script:TagIndex.Remove($TagName)
        }
    }
}

function Register-XamlControls {
    param([System.Collections.Generic.List[string]]$ControlNames, $Window)
    foreach ($name in $ControlNames) {
        $ctrl = $Window.FindName($name)
        if ($ctrl) {
            Register-Entity -Name $name -Control $ctrl -ParentName $null
        }
    }
}
