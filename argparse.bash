#!/usr/bin/env bash

# Use python's argparse module in shell scripts
#
# The function `argparse` parses its arguments using
# argparse.ArgumentParser; the parser is defined in the function's
# stdin.
#
# Executing ``argparse.bash`` (as opposed to sourcing it) prints a
# script template.
#
# https://github.com/nhoffman/argparse-bash
# MIT License - Copyright (c) 2015 Noah Hoffman
# https://github.com/5xops/argparse-bash
# MIT License - Copyright (c) 2023 5xops

argparse(){
    argparser=$(mktemp 2>/dev/null || mktemp -t argparser)
    cat > "$argparser" <<EOF
# coding: utf-8
from __future__ import print_function
import sys
import argparse
class MyArgumentParser(argparse.ArgumentParser):
    def print_help(self, file=None):
        """Print help and exit with error"""
        super(MyArgumentParser, self).print_help(file=file)
        sys.exit(1)
parser = MyArgumentParser(prog="$PROCNAME" + " $ACTION",
            formatter_class=argparse.ArgumentDefaultsHelpFormatter)
EOF

    # stdin to this function should contain the parser definition
    cat >> "$argparser"

    cat >> "$argparser" <<EOF
args = parser.parse_args()
for arg in [a for a in dir(args) if not a.startswith('_')]:
    key = arg.upper()
    value = getattr(args, arg, None)
    if isinstance(value, bool):
        print('{0}="{1}";'.format(key, 'yes' if value else 'no'))
    elif value is None:
        print('{0}="{1}";'.format(key, ''))
    elif isinstance(value, list):
        print('{0}=({1});'.format(key, ' '.join('"{0}"'.format(s) for s in value)))
    else:
        print('{0}="{1}";'.format(key, value))
EOF

    # Define variables corresponding to the options if the args can be
    # parsed without errors; otherwise, print the text of the error
    # message.
    if $PYTHON "$argparser" "$@" &> /dev/null; then
        set -o noglob
        eval $($PYTHON "$argparser" "$@")
        set +o noglob
        retval=0
    else
        $PYTHON "$argparser" "$@"
        retval=1
    fi

    /bin/rm -f "$argparser"
    return $retval
}

# print a script template when this script is executed
if [[ $0 == *argparse.bash ]]; then
    cat <<FOO
#!/usr/bin/env bash

source \$(dirname \$0)/argparse.bash || exit 1
argparse "\$@" <<EOF || exit 1
parser.add_argument('infile')
parser.add_argument('-o', '--outfile')

EOF

echo "INFILE: \${INFILE}"
echo "OUTFILE: \${OUTFILE}"
FOO
fi
