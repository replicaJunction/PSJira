﻿. $PSScriptRoot\Shared.ps1

InModuleScope JiraPS {

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
    $SuppressImportModule = $true
    . $PSScriptRoot\Shared.ps1

    $jiraServer = 'http://jiraserver.example.com'
    $issueID = 12345
    $issueKey = 'TEST-1'

    Describe "Remove-JiraIssueWatcher" {

        Mock Get-JiraIssue {
            ShowMockInfo 'Get-JiraIssue' 'InputObject', 'ServerName'
            [PSCustomObject] @{
                ID      = $issueID;
                Key     = $issueKey;
                RestUrl = "$jiraServer/rest/api/latest/issue/$issueID";
            }
        }

        Mock Invoke-JiraMethod -ParameterFilter {$Method -eq 'DELETE' -and $URI -eq "$jiraServer/rest/api/latest/issue/$issueID/watchers?username=fred"} {
            ShowMockInfo 'Invoke-JiraMethod' -Params 'Uri', 'Method'
        }

        # Generic catch-all. This will throw an exception if we forgot to mock something.
        Mock Invoke-JiraMethod {
            ShowMockInfo 'Invoke-JiraMethod' -Params 'Uri', 'Method'
            throw "Unidentified call to Invoke-JiraMethod"
        }

        #############
        # Tests
        #############

        Context "Sanity checking" {
            $command = Get-Command -Name Remove-JiraIssueWatcher

            defParam $command 'Watcher'
            defParam $command 'Issue'
            defParam $command 'Credential'
        }

        Context "Behavior testing" {

            It "Removes a Watcher from an issue in JIRA" {
                $WatcherResult = Remove-JiraIssueWatcher -Watcher 'fred' -Issue $issueKey
                $WatcherResult | Should BeNullOrEmpty

                # Get-JiraIssue should be used to identiyf the issue parameter
                Assert-MockCalled -CommandName Get-JiraIssue -Exactly -Times 1 -Scope It

                # Invoke-JiraMethod should be used to add the Watcher
                Assert-MockCalled -CommandName Invoke-JiraMethod -Exactly -Times 1 -Scope It
            }

            It "Accepts pipeline input from Get-JiraIssue" {
                $WatcherResult = Get-JiraIssue -InputObject $issueKey | Remove-JiraIssueWatcher -Watcher 'fred'
                $WatcherResult | Should BeNullOrEmpty

                # Get-JiraIssue should be called once here, and once inside Add-JiraIssueWatcher (to identify the InputObject parameter)
                Assert-MockCalled -CommandName Get-JiraIssue -Exactly -Times 2 -Scope It
                Assert-MockCalled -CommandName Invoke-JiraMethod -Exactly -Times 1 -Scope It
            }

            It "Passes the -ServerName parameter to Get-JiraIssue if specified" {
                Remove-JiraIssueWatcher -Watcher 'fred' -Issue $issueKey -ServerName 'testServer' | Out-Null
                Assert-MockCalled -CommandName Get-JiraIssue -ParameterFilter {$ServerName -eq 'testServer'}
            }
        }
    }
}
