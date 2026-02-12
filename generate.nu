#!/usr/bin/env nu
# Generate Dhall types from CRD JSON schemas
# Usage: nu generate.nu <crds-path> <output-path>
#
# This script converts JSON schema files from CRDs-catalog into Dhall type definitions,
# following the pattern established by dhall-kubernetes and dhall-tekton.

# Convert JSON schema type to Dhall type
def json_to_dhall_type [json_type: string, prop: record] {
    match $json_type {
        "string" => "Text"
        "integer" => "Integer"
        "number" => "Double"
        "boolean" => "Bool"
        "array" => {
            if ($prop | get -o items | is-not-empty) {
                let item_type = ($prop.items | get -o type | default "string")
                $"List (json_to_dhall_type $item_type $prop.items)"
            } else {
                "List Text"
            }
        }
        "object" => { "{ }" }
        _ => "Text"
    }
}

# Convert a property to Dhall field
def convert_property [name: string, prop: any, required: bool] {
    # Handle non-record properties
    if ($prop | describe | str starts-with "record") == false {
        return $"($name) : Text"
    }

    # Handle $ref
    if ($prop | get -o "$ref" | is-not-empty) {
        let ref = ($prop | get "$ref")
        let ref_name = ($ref | split row "/" | last)
        return $"($name) : Text"  # Simplify refs to Text for now
    }

    # Handle oneOf/anyOf
    if ($prop | get -o oneOf | is-not-empty) or ($prop | get -o anyOf | is-not-empty) {
        if $required {
            return $"($name) : Text"
        } else {
            return $"($name) : Optional Text"
        }
    }

    let prop_type = ($prop | get -o type | default "string")

    # Handle enum
    if ($prop | get -o enum | is-not-empty) {
        let enum_vals = ($prop | get enum)
        if ($enum_vals | all {|v| ($v | describe) == "string" }) {
            let union = ($enum_vals | each {|v| $"\"($v)\""} | str join " | ")
            if $required {
                return $"($name) : < ($union) >"
            } else {
                return $"($name) : Optional < ($union) >"
            }
        }
    }

    # Handle array
    if $prop_type == "array" {
        let items = ($prop | get -o items | default {})
        let item_type = if ($items | get -o type | is-not-empty) {
            json_to_dhall_type ($items | get type) $items
        } else {
            "Text"
        }
        let base_type = $"List ($item_type)"
        if $required {
            return $"($name) : ($base_type)"
        } else {
            return $"($name) : Optional ($base_type)"
        }
    }

    # Handle object with properties
    if $prop_type == "object" {
        let empty_record = "{ }"
        if ($prop | get -o properties | is-not-empty) {
            # For complex nested objects, simplify to a record placeholder
            if $required {
                return $"($name) : ($empty_record)"
            } else {
                return $"($name) : Optional ($empty_record)"
            }
        } else if ($prop | get -o additionalProperties | is-not-empty) {
            let map_type = "List { mapKey : Text, mapValue : Text }"
            if $required {
                return $"($name) : ($map_type)"
            } else {
                return $"($name) : Optional (($map_type))"
            }
        }
        if $required {
            return $"($name) : ($empty_record)"
        } else {
            return $"($name) : Optional ($empty_record)"
        }
    }

    # Simple types
    let base_type = (json_to_dhall_type $prop_type $prop)
    if $required {
        $"($name) : ($base_type)"
    } else {
        $"($name) : Optional ($base_type)"
    }
}

# Generate Dhall type file content
def generate_type_file [schema: record, crd_name: string, version: string] {
    let props = ($schema | get -o properties | default {})
    let required_list = ($schema | get -o required | default [])

    if ($props | is-empty) {
        return "{ }"
    }

    let fields = ($props | columns | each {|name|
        let prop = ($props | get $name)
        let is_required = ($name in $required_list)
        convert_property $name $prop $is_required
    })

    if ($fields | is-empty) {
        "{ }"
    } else {
        "{\n  " + ($fields | str join "\n, ") + "\n}"
    }
}

# Generate Dhall defaults file content
def generate_default_file [crd_name: string, version: string, crd_group: string] {
    # Derive kind from crd_name: certificate -> Certificate
    let kind = ($crd_name | str capitalize)
    let api_version = $"($crd_group)/($version)"

    $"{ apiVersion = \"($api_version)\", kind = \"($kind)\" }"
}

# Generate Dhall schema file content
def generate_schema_file [crd_name: string, version_dir: string] {
    $"{ Type = ./../../types/($version_dir)/($crd_name).dhall
, default = ./../../defaults/($version_dir)/($crd_name).dhall
}"
}

# Sanitize name for Dhall identifier
def sanitize_dhall_name [name: string] {
    $"`($name)`"
}

# Process a single CRD JSON file
def process_crd_file [json_path: string, output_dir: string, crd_group: string] {
    let schema = (open $json_path)
    
    # Extract CRD name and version from filename: certificate_v1.json
    let filename = ($json_path | path parse | get stem)
    let parts = ($filename | split row "_v")
    let crd_name = ($parts | first)
    let version = if ($parts | length) > 1 {
        "v" + ($parts | last)
    } else {
        "v1"
    }

    let version_dir = $"com.github.($crd_group).($version)"

    # Create directories
    let types_dir = $"($output_dir)/types/($version_dir)"
    let defaults_dir = $"($output_dir)/defaults/($version_dir)"
    let schemas_dir = $"($output_dir)/schemas/($version_dir)"

    mkdir $types_dir
    mkdir $defaults_dir
    mkdir $schemas_dir

    # Generate type file
    let type_content = (generate_type_file $schema $crd_name $version)
    $type_content | save -f $"($types_dir)/($crd_name).dhall"

    # Generate defaults file
    let default_content = (generate_default_file $crd_name $version $crd_group)
    $default_content | save -f $"($defaults_dir)/($crd_name).dhall"

    # Generate schema file
    let schema_content = (generate_schema_file $crd_name $version_dir)
    $schema_content | save -f $"($schemas_dir)/($crd_name).dhall"

    print $"  Generated: ($crd_name).($version)"
}

# Generate aggregate files for a CRD group
def generate_group_aggregates [group_dir: string] {
    let types_dir = $"($group_dir)/types"
    let schemas_dir = $"($group_dir)/schemas"
    let defaults_dir = $"($group_dir)/defaults"

    # Generate types.dhall for this group
    if ($types_dir | path exists) {
        let type_files = (glob $"($types_dir)/*/*.dhall")
        if ($type_files | is-not-empty) {
            let entries = ($type_files | each {|tf|
                let version_dir = ($tf | path dirname | path basename)
                let type_name = ($tf | path parse | get stem)
                $", ($type_name) = ./types/($version_dir)/($type_name).dhall"
            })
            let content = "{\n  " + (($entries | str join "\n") | str substring 2..) + "\n}"
            $content | save -f $"($group_dir)/types.dhall"
        }
    }

    # Generate schemas.dhall for this group
    if ($schemas_dir | path exists) {
        let schema_files = (glob $"($schemas_dir)/*/*.dhall")
        if ($schema_files | is-not-empty) {
            let entries = ($schema_files | each {|sf|
                let version_dir = ($sf | path dirname | path basename)
                let schema_name = ($sf | path parse | get stem)
                $", ($schema_name) = ./schemas/($version_dir)/($schema_name).dhall"
            })
            let content = "{\n  " + (($entries | str join "\n") | str substring 2..) + "\n}"
            $content | save -f $"($group_dir)/schemas.dhall"
        }
    }

    # Generate defaults.dhall for this group
    if ($defaults_dir | path exists) {
        let default_files = (glob $"($defaults_dir)/*/*.dhall")
        if ($default_files | is-not-empty) {
            let entries = ($default_files | each {|df|
                let version_dir = ($df | path dirname | path basename)
                let default_name = ($df | path parse | get stem)
                $", ($default_name) = ./defaults/($version_dir)/($default_name).dhall"
            })
            let content = "{\n  " + (($entries | str join "\n") | str substring 2..) + "\n}"
            $content | save -f $"($group_dir)/defaults.dhall"
        }
    }
}

# Generate main aggregate files
def generate_main_aggregates [base_dir: string, crd_groups: list<string>] {
    # Generate types.dhall
    let types_entries = ($crd_groups | each {|g|
        $", (sanitize_dhall_name $g) = ./($g)/types.dhall"
    })
    let types_content = "{\n  " + (($types_entries | str join "\n") | str substring 2..) + "\n}"
    $types_content | save -f $"($base_dir)/types.dhall"

    # Generate schemas.dhall
    let schemas_entries = ($crd_groups | each {|g|
        $", (sanitize_dhall_name $g) = ./($g)/schemas.dhall"
    })
    let schemas_content = "{\n  " + (($schemas_entries | str join "\n") | str substring 2..) + "\n}"
    $schemas_content | save -f $"($base_dir)/schemas.dhall"

    # Generate defaults.dhall
    let defaults_entries = ($crd_groups | each {|g|
        $", (sanitize_dhall_name $g) = ./($g)/defaults.dhall"
    })
    let defaults_content = "{\n  " + (($defaults_entries | str join "\n") | str substring 2..) + "\n}"
    $defaults_content | save -f $"($base_dir)/defaults.dhall"
}

# Main function
def main [
    crds_path: string = "../CRDs-catalog"  # Path to CRDs-catalog
    output_path: string = "."              # Output directory
] {
    let crds_dir = ($crds_path | path expand)
    let out_dir = ($output_path | path expand)

    print $"Scanning CRDs from: ($crds_dir)"

    if not ($crds_dir | path exists) {
        print $"Error: CRDs path not found: ($crds_dir)"
        exit 1
    }

    let skip_dirs = [".git", "Utilities", ".github", "openshift", ".jj"]

    # Get all CRD group directories
    let crd_dirs = (ls $crds_dir 
        | where type == "dir"
        | where {|it| not (($it.name | path basename) in $skip_dirs)}
        | get name
        | sort
    )

    print $"Found ($crd_dirs | length) CRD groups"

    mut total_crds = 0
    mut crd_groups = []

    for crd_dir in $crd_dirs {
        let crd_group = ($crd_dir | path basename)
        let json_files = (glob $"($crd_dir)/*.json")

        if ($json_files | is-empty) {
            continue
        }

        $crd_groups = ($crd_groups | append $crd_group)
        print $"\nProcessing ($crd_group): ($json_files | length) CRDs"

        # Create output directory for this CRD group
        let group_out_dir = $"($out_dir)/($crd_group)"
        mkdir $group_out_dir

        for json_file in $json_files {
            process_crd_file $json_file $group_out_dir $crd_group
            $total_crds = $total_crds + 1
        }

        # Generate aggregate files for this group
        generate_group_aggregates $group_out_dir
    }

    print "\nGenerating aggregate files..."
    generate_main_aggregates $out_dir $crd_groups

    print "\n=================================================="
    print "Generation complete!"
    print $"Total CRDs processed: ($total_crds)"
    print $"CRD groups: ($crd_groups | length)"
}
