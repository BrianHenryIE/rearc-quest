* Always lint code (`terraform fmt` etc.)
* PRs should contain instructions for manual verification of changes. (i.e. checkout branch, build, start Docker, and precise instructions to verify changes, whether opening a UI screen or running CLI commands, aws, curl etc, to check a value)
* PR descriptions should link to documentation, i.e. a summary of the Terraform changes should link to the developer.hashicorp.com/terraform module pages
* code-review:code-review should check that current best practices are followed, i.e. deprecated modules are not used
* 