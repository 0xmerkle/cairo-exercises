# Repo of cairo exercises and walkthroughs

## Running programs
The general form of running a cairo program looks like this:
```
cairo-compile <your_file_name>.cairo --output <your_file_name_compiled>.json

cairo-run --program=<your_file_name_compiled>.json \
    --print_output --layout=small \
    --program_input=<your_input_file_name>.json
```