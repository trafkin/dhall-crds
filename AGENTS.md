# AGENTS.md - dhall-crds

Copyright 2024 dhall-crds contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---

This file provides guidance for AI coding agents working on this repository.

## Project Overview

**dhall-crds** is a Dhall type library providing type-safe bindings for Kubernetes CRDs. It generates Dhall types from the [CRDs-catalog](https://github.com/datreeio/CRDs-catalog) JSON schemas, following conventions from [dhall-kubernetes](https://github.com/dhall-lang/dhall-kubernetes).

### Languages Used
- **Dhall**: Primary output language
- **Nushell**: Code generation scripts (`generate.nu`, `regenerate.nu`)

## Build/Generation Commands

### Full Regeneration
```bash
nu regenerate.nu --clean   # Clean and regenerate all types
nu regenerate.nu            # Regenerate without cleaning
nu regenerate.nu /path/to/CRDs-catalog ./output  # Custom paths
```

### Generate Types
```bash
nu generate.nu <crds-path> <output-path>
nu generate.nu ../CRDs-catalog .  # Default
```

### Type Checking (Dhall)
```bash
dhall type --file ./package.dhall        # Type-check a file
dhall format --check <file.dhall>       # Type-check and format
dhall-to-yaml --file <file.dhall>       # Convert to YAML
```

### Running Single Tests
```bash
dhall type --file ./cert-manager.io/types/com.github.cert-manager.io.v1/certificate.dhall
dhall type --file ./cert-manager.io/types.dhall
```

## Project Structure

```
dhall-crds/
├── package.dhall           # Main entry point
├── Kubernetes.dhall        # Re-exports dhall-kubernetes types
├── types.dhall             # Aggregate of all CRD group types
├── schemas.dhall           # Aggregate of all CRD group schemas
├── defaults.dhall          # Aggregate of all CRD group defaults
├── generate.nu             # JSON schema to Dhall converter
├── regenerate.nu           # Regeneration orchestrator
└── <crd-group>/            # ~500+ CRD group directories
    ├── types.dhall         # Group-level type exports
    ├── schemas.dhall       # Group-level schema exports
    ├── defaults.dhall      # Group-level default exports
    └── types|schemas|defaults/com.github.<group>.<version>/<resource>.dhall
```

## Code Style Guidelines

### Dhall Files

#### Formatting
- Use 2-space indentation
- Opening brace `{` on same line as declaration
- Fields separated by newline and comma prefix: `\n, fieldName = ...`
- Closing brace `}` on its own line

#### Record Syntax
```dhall
{
  fieldOne : Text
, fieldTwo : Optional Integer
, fieldThree : List Text
}

-- Single-line for simple records
{ apiVersion = "v1", kind = "Pod" }
```

#### Types
- Required fields: `fieldName : Type`
- Optional fields: `fieldName : Optional Type`
- Lists: `List Type`
- Maps: `List { mapKey : Text, mapValue : Text }`
- Empty records: `{ }`
- Union types (enums): `< "v1" | "v2" >`

#### Imports
- Use relative paths: `./path/to/file.dhall`
- Remote imports: `https://raw.githubusercontent.com/dhall-lang/dhall-kubernetes/master/package.dhall`

#### Naming Conventions
- File names: lowercase, match CRD resource name (`certificate.dhall`)
- Directory names: match API group exactly (`cert-manager.io`)
- Version directories: `com.github.<group>.<version>` format

### Nushell Scripts (generate.nu, regenerate.nu)

- Use 4-space indentation inside functions
- Function definitions: `def function_name [param: type] { }`
- Variable declarations: `let varName = value`
- Mutable variables: `mut varName = value`
- Function names: `snake_case`
- Script files: `lowercase.nu`

#### Error Handling
```nushell
if not ($path | path exists) {
    print $"Error: path not found: ($path)"
    exit 1
}
```

## Important Considerations

### Do NOT Modify Generated Files
- All files under `<crd-group>/` directories are generated
- Edit `generate.nu` to change output patterns
- Run `nu regenerate.nu --clean` after changes

### Manually Maintained Files
- `package.dhall`, `Kubernetes.dhall`, `generate.nu`, `regenerate.nu`

### Skip Directories
The generator skips: `.git`, `.github`, `.jj`, `Utilities`, `openshift`

### Dependencies
- **Nushell**: Required for running generation scripts
- **Dhall CLI**: Required for type-checking (`dhall`, `dhall-to-yaml`)
- **CRDs-catalog**: Source JSON schemas (clone separately)

### Type Mapping (JSON Schema -> Dhall)
| JSON Schema | Dhall Type |
|-------------|------------|
| `string`    | `Text`     |
| `integer`   | `Integer`  |
| `number`    | `Double`   |
| `boolean`   | `Bool`     |
| `array`     | `List T`   |
| `object`    | `{ }`      |
| `enum`      | `< "v1" \| "v2" >` |
