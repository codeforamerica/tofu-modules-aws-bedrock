# Code for America OpenTofu Module Template

[![GitHub Release][badge-release]][latest-release]

Use this template repository to create new OpenTofu modules. Follow the steps
below to use this repository:

1. Click the "Use this template" button to create a new repository
1. Name your new repository using the format `todu-modules-<provider>-<module>`
1. Update the repository Pull Requests settings to allow only **squash merging** with a default commit message of "Pull request title and commit details" for automated releases
1. Add the files necessary to support your module to the root of your new
   repository
1. Update the `README.md` file with the appropriate information for your module.
   Make sure you update any references to this template repository with your new
   repository
1. Update the [codeforamerica/tofu-modules][tofu-modules] repository to include
   your new module in the main `README.md` and the documentation

## Usage

Add this module to your `main.tf` (or appropriate) file and configure the inputs
to match your desired configuration. For example:

[//]: # (TODO: Update to match your module's name and inputs)

```hcl
module "module_name" {
  source = "github.com/codeforamerica/tofu-modules-template?ref=1.0.0"

  project = "my-project"
  environment = "development"
}
```

Make sure you re-run `tofu init` after adding the module to your configuration.

```bash
tofu init
tofu plan
```

To update the source for this module, pass `-upgrade` to `tofu init`:

```bash
tofu init -upgrade
```

## Inputs

[//]: # (TODO: Replace the following with your own inputs)

| Name        | Description                                   | Type     | Default | Required |
|-------------|-----------------------------------------------|----------|---------|----------|
| project     | Name of the project.                          | `string` | n/a     | yes      |
| environment | Environment for the project.                  | `string` | `"dev"` | no       |
| tags        | Optional tags to be applied to all resources. | `list`   | `[]`    | no       |

## Outputs

[//]: # (TODO: Replace the following with your own outputs)

| Name     | Description                       | Type     |
|----------|-----------------------------------|----------|
| id       | Id of the newly created resource. | `string` |


## Contributing

This repository uses [pre-commit](https://pre-commit.com) to enforce code
style checks before each commit. Install it once after cloning:

**1. Install pre-commit**

```sh
brew install pre-commit
```

**2. Install the git hook**

```sh
pre-commit install
```

This symlinks the hook into `.git/hooks/pre-commit`. The checks will now run
automatically on every `git commit`. To run them manually against all files:

```sh
pre-commit run --all-files
```

Follow the [contributing guidelines][contributing] to contribute to this
repository.

[badge-release]: https://img.shields.io/github/v/release/codeforamerica/tofu-modules-template?logo=github&label=Latest%20Release
[contributing]: CONTRIBUTING.md
[latest-release]: https://github.com/codeforamerica/tofu-modules-template/releases/latest
[tofu-modules]: https://github.com/codeforamerica/tofu-modules
