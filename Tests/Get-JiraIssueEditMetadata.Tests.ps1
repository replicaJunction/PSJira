. $PSScriptRoot\Shared.ps1

InModuleScope JiraPS {

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
    $SuppressImportModule = $true
    . $PSScriptRoot\Shared.ps1

    Describe "Get-JiraIssueEditMetadata" {

        if ($ShowDebugText) {
            Mock 'Write-Debug' {
                Write-Host "       [DEBUG] $Message" -ForegroundColor Yellow
            }
        }

        $issueID = 12345
        $issueKey = 'TEST-1'

        # If we don't override this in a context or test, we don't want it to
        # actually try to query a JIRA instance
        Mock Invoke-JiraMethod {
            ShowMockInfo 'Invoke-JiraMethod' 'Method', 'URI', 'ServerName'
        }

        Context "Sanity checking" {
            $command = Get-Command -Name Get-JiraIssueEditMetadata

            function defParam($name) {
                It "Has a -$name parameter" {
                    $command.Parameters.Item($name) | Should Not BeNullOrEmpty
                }
            }

            defParam 'Issue'
            defParam 'Credential'
        }

        Context "Behavior testing" {

            $restResult = ConvertFrom-Json2 @'
{
    "fields": {
        "summary": {
            "required": true,
            "schema": {
                "type": "string",
                "system": "summary"
            },
            "name": "Summary",
            "hasDefaultValue": false,
            "operations": [
                "set"
            ]
        },
        "issuetype": {
            "required": true,
            "schema": {
                "type": "issuetype",
                "system": "issuetype"
            },
            "name": "Issue Type",
            "hasDefaultValue": false,
            "operations": [],
            "allowedValues": [
                {
                    "self": "https://jira.example.com/rest/api/2/issuetype/2",
                    "id": "2",
                    "description": "This is a test issue type",
                    "iconUrl": "https://jira.example.com/images/icons/issuetypes/newfeature.png",
                    "name": "Test Issue Type",
                    "subtask": false
                }
            ]
        },
        "description": {
            "required": false,
            "schema": {
                "type": "string",
                "system": "description"
            },
            "name": "Description",
            "hasDefaultValue": false,
            "operations": [
                "set"
            ]
        },
        "project": {
            "required": true,
            "schema": {
                "type": "project",
                "system": "project"
            },
            "name": "Project",
            "hasDefaultValue": false,
            "operations": [
                "set"
            ],
            "allowedValues": [
                {
                    "self": "https://jira.example.com/rest/api/2/project/10003",
                    "id": "10003",
                    "key": "TEST",
                    "name": "Test Project",
                    "projectCategory": {
                        "self": "https://jira.example.com/rest/api/2/projectCategory/10000",
                        "id": "10000",
                        "description": "All Project Catagories",
                        "name": "All Project"
                    }
                }
            ]
        },
        "reporter": {
            "required": true,
            "schema": {
                "type": "user",
                "system": "reporter"
            },
            "name": "Reporter",
            "autoCompleteUrl": "https://jira.example.com/rest/api/latest/user/search?username=",
            "hasDefaultValue": false,
            "operations": [
                "set"
            ]
        },
        "assignee": {
            "required": false,
            "schema": {
                "type": "user",
                "system": "assignee"
            },
            "name": "Assignee",
            "autoCompleteUrl": "https://jira.example.com/rest/api/latest/user/assignable/search?issueKey=null&username=",
            "hasDefaultValue": false,
            "operations": [
                "set"
            ]
        },
        "priority": {
            "required": false,
            "schema": {
                "type": "priority",
                "system": "priority"
            },
            "name": "Priority",
            "hasDefaultValue": true,
            "operations": [
                "set"
            ],
            "allowedValues": [
                {
                    "self": "https://jira.example.com/rest/api/2/priority/1",
                    "iconUrl": "https://jira.example.com/images/icons/priorities/blocker.png",
                    "name": "Blocker",
                    "id": "1"
                },
                {
                    "self": "https://jira.example.com/rest/api/2/priority/2",
                    "iconUrl": "https://jira.example.com/images/icons/priorities/critical.png",
                    "name": "Critical",
                    "id": "2"
                },
                {
                    "self": "https://jira.example.com/rest/api/2/priority/3",
                    "iconUrl": "https://jira.example.com/images/icons/priorities/major.png",
                    "name": "Major",
                    "id": "3"
                },
                {
                    "self": "https://jira.example.com/rest/api/2/priority/4",
                    "iconUrl": "https://jira.example.com/images/icons/priorities/minor.png",
                    "name": "Minor",
                    "id": "4"
                },
                {
                    "self": "https://jira.example.com/rest/api/2/priority/5",
                    "iconUrl": "https://jira.example.com/images/icons/priorities/trivial.png",
                    "name": "Trivial",
                    "id": "5"
                }
            ]
        },
        "labels": {
            "required": false,
            "schema": {
                "type": "array",
                "items": "string",
                "system": "labels"
            },
            "name": "Labels",
            "autoCompleteUrl": "https://jira.example.com/rest/api/1.0/labels/suggest?query=",
            "hasDefaultValue": false,
            "operations": [
                "add",
                "set",
                "remove"
            ]
        }
    }
}
'@

            Mock Get-JiraIssue {
                [PSCustomObject] @{
                    ID      = $issueID;
                    Key     = $issueKey;
                    RestUrl = "$jiraServer/rest/api/latest/issue/$issueID";
                }
            }

            It "Queries Jira for metadata information about editing an issue" {
                { Get-JiraIssueEditMetadata -Issue $issueID } | Should Not Throw
                Assert-MockCalled -CommandName Invoke-JiraMethod -Exactly -Times 1 -Scope It -ParameterFilter {$Method -eq 'Get' -and $URI -like "*/rest/api/*/issue/$issueID/editmeta"}
            }

            It "Passes the -ServerName parameter to Invoke-JiraMethod if specified" {
                Get-JiraIssueEditMetadata -Issue $issueID -ServerName 'testServer' | Out-Null
                Assert-MockCalled -CommandName Invoke-JiraMethod -ParameterFilter {$ServerName -eq 'testServer'}
            }

            It "Uses ConvertTo-JiraEditMetaField to output EditMetaField objects if JIRA returns data" {

                # This is a simplified version of what JIRA will give back
                Mock Invoke-JiraMethod {
                    @{
                        fields = [PSCustomObject] @{
                            'a' = 1;
                            'b' = 2;
                        }
                    }
                }
                Mock ConvertTo-JiraEditMetaField {}

                { Get-JiraIssueEditMetadata -Issue $issueID } | Should Not Throw
                Assert-MockCalled -CommandName Invoke-JiraMethod -Exactly -Times 1 -Scope It -ParameterFilter {$Method -eq 'Get' -and $URI -like "*/rest/api/*/issue/$issueID/editmeta"}

                # There are 2 example fields in our mock above, but they should
                # be passed to Convert-JiraCreateMetaField as a single object.
                # The method should only be called once.
                Assert-MockCalled -CommandName ConvertTo-JiraEditMetaField -Exactly -Times 1 -Scope It
            }
        }
    }
}
