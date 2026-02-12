#!/usr/bin/env nu
# Regenerate Dhall types from CRDs-catalog
# Usage: nu regenerate.nu [crds-path] [output-path]
#
# This script orchestrates the regeneration of Dhall types from CRD JSON schemas.
#
# Examples:
#   nu regenerate.nu                           # Use defaults: ../CRDs-catalog -> .
#   nu regenerate.nu /path/to/CRDs-catalog     # Specify CRDs path
#   nu regenerate.nu ../CRDs-catalog ./output  # Specify both paths
#   nu regenerate.nu --clean                   # Clean and regenerate

def main [
    crds_path: string = "../CRDs-catalog"  # Path to CRDs-catalog directory
    output_path: string = "."               # Output directory for generated Dhall files
    --clean (-c)                            # Clean existing generated directories before regenerating
] {
    let script_dir = ($env.FILE_PWD? | default (pwd))
    let crds_dir = ($crds_path | path expand)
    let out_dir = ($output_path | path expand)
    let generate_script = ($script_dir | path join "generate.nu")

    print $"(ansi cyan)dhall-crds generator(ansi reset)"
    print $"CRDs source: ($crds_dir)"
    print $"Output dir:  ($out_dir)"
    print ""

    # Validate CRDs directory exists
    if not ($crds_dir | path exists) {
        print $"(ansi red)Error:(ansi reset) CRDs directory not found: ($crds_dir)"
        exit 1
    }

    # Validate generate.nu exists
    if not ($generate_script | path exists) {
        print $"(ansi red)Error:(ansi reset) generate.nu not found at: ($generate_script)"
        exit 1
    }

    # Count CRD groups
    let skip_dirs = [".git", "Utilities", ".github", "openshift", ".jj"]
    let crd_groups = (
        ls $crds_dir 
        | where type == "dir" 
        | where {|it| not ($it.name | path basename | $in in $skip_dirs)}
        | length
    )

    print $"Found ($crd_groups) CRD groups to process"

    # Clean existing generated directories if requested
    if $clean {
        print $"(ansi yellow)Cleaning existing generated directories...(ansi reset)"
        let keep_files = ["generate.nu", "regenerate.nu", "generate.dhall", "package.dhall", "Kubernetes.dhall", "generate.py"]
        ls $out_dir 
        | where type == "dir"
        | where {|it| not (($it.name | path basename) in [".", "..", ".git"])}
        | each {|dir| 
            rm -rf $dir.name
        }
        # Also remove generated aggregate files
        ["types.dhall", "schemas.dhall", "defaults.dhall"] | each {|f|
            let file_path = ($out_dir | path join $f)
            if ($file_path | path exists) {
                rm $file_path
            }
        }
        print "Cleaned."
    }

    print ""
    print $"(ansi green)Running generation...(ansi reset)"
    print ""

    # Run the Nu generation script
    nu $generate_script $crds_dir $out_dir

    print ""
    print $"(ansi green)Done!(ansi reset)"
}
