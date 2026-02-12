# dhall-crds

**Warning: This repository was AI-generated.**

This project provides Dhall type definitions for Kubernetes Custom Resource Definitions (CRDs). The types are automatically generated from the [CRDs-catalog](https://github.com/datreeio/CRDs-catalog) JSON schemas.

## Usage

Import the package in your Dhall files:

```dhall
let dhall-crds = ./package.dhall

in  dhall-crds.types.cert-manager.io.certificate
```

## License

Licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.
