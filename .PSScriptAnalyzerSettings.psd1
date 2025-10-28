# PSScriptAnalyzer settings for PowerShell code quality
@{
    # Enable all rules by default
    IncludeDefaultRules = $true

    # Severity levels to check
    Severity = @('Error', 'Warning', 'Information')

    # Exclude specific rules if needed
    ExcludeRules = @(
        # Add rules to exclude here if necessary
    )

    # Custom rules
    Rules = @{
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
            CheckParameter = $false
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing = @{
            Enable = $true
        }
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false
            BlockComment = $true
            VSCodeSnippetCorrection = $true
            Placement = 'before'
        }
    }
}
