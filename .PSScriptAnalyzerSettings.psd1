# PSScriptAnalyzer settings for PowerShell code quality
@{
    # Enable all rules by default
    IncludeDefaultRules = $true

    # Severity levels to check
    Severity            = @('Error', 'Warning', 'Information')

    # Exclude specific rules if needed
    ExcludeRules = @(
        # Alignment rules can be overly strict for functional code
        'PSAlignAssignmentStatement',
        # BOM encoding not required for all files
        'PSUseBOMForUnicodeEncodedFile',
        # Unused parameter warnings in test mocks are false positives
        'PSReviewUnusedParameter',
        # Write-Host is acceptable in profile.ps1 files for colored prompts
        'PSAvoidUsingWriteHost',
        # Whitespace consistency can be overly strict for configuration files
        'PSUseConsistentWhitespace',
        # Comment help is informational and not required for helper functions
        'PSProvideCommentHelp',
        # OutputType is informational and not critical
        'PSUseOutputTypeCorrectly'
    )

    # Custom rules
    Rules               = @{
        PSUseApprovedVerbs               = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases        = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSUseConsistentIndentation       = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace        = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $true
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator                  = $true
            CheckParameter                  = $false
        }
        PSUseCorrectCasing               = @{
            Enable = $true
        }
        PSProvideCommentHelp             = @{
            Enable                  = $true
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $true
            Placement               = 'before'
        }
    }
}
