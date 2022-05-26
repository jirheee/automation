#!/usr/bin/env bash


run_opt()
{
  dir=$1
  input=$2
  opt=$3
  
  cargo run --features=build-bin -- --${opt} --iroutput -i "$dir/$input.ir" -o "$dir/$opt.ir" > "$dir/${opt}_stdout.txt" 2> "$dir/${opt}_stderr.txt"
}


run_O1_once()
{
  dir=$1

  optimizations=("simplify-cfg" "mem2reg" "gvn" "deadcode")

  for ((i=0; i<${#optimizations[@]}; i++)); do
    input=$([ "$i" == 0 ] && echo "start" || echo "${optimizations[$(($i-1))]}")
    opt=${optimizations[$i]}
    run_opt $dir $input $opt
  done
}

opt_until_converge()
{
  output_dir=$1
  opt_target=$2

  opt_count=1

  while [ 1 ]
  do
    dir="$output_dir/$opt_target/trial_$opt_count"

    mkdir -p "$dir"
    cp "$output_dir/$opt_target/trial_$(($opt_count-1))/deadcode.ir" "$dir/start.ir"

    run_O1_once $dir

    OUTPUT=$(diff -u --color "$dir/start.ir" "$dir/deadcode.ir")

    echo "$OUTPUT" > "$dir/diff.txt"

    if test -z "$OUTPUT" 
    then
      break
    fi

    opt_count=$(($opt_count+1))
  done

  final_output_path="$output_dir/$opt_target/final.ir"
  cp "$output_dir/$opt_target/trial_$opt_count/deadcode.ir" $final_output_path
  OUTPUT=$(diff -u --color $final_output_path "examples/opt/$opt_target") 

  if test -z "$OUTPUT" 
  then
    RETURN_TXT="\033[;32m[PASS]$opt_target\033[0m\n"
  else
    RETURN_TXT="\033[;31m[FAIL]$opt_target\033[0m\n"
  fi

  echo "$OUTPUT"> "$output_dir/$opt_target/final_diff.txt"
  echo -e $RETURN_TXT
}

run_folder()
{
  input_folder=$1
  
  output_dir="logs/`date +%y%m%d/%T`"
  echo "logging in $output_dir"

  mkdir -p $output_dir

  for file in "$input_folder"/*.ir;
  do
    basename=$(basename -- $file)
    mkdir -p "$output_dir/$basename/trial_0"
    cp $file "$output_dir/$basename/trial_0/deadcode.ir"
    RETURN=$(opt_until_converge $output_dir $basename)
    echo -e $RETURN
  done
}

run_one()
{
  basename=$1
  output_dir="logs/out"
  mkdir -p "$output_dir/$basename/trial_0"
  cp "examples/ir0/$basename" "$output_dir/$basename/trial_0/deadcode.ir"

  opt_until_converge $output_dir $basename
}

help_prompt()
{
   echo "Usage: $0"
   echo -e "\t-a run -O1 for all ir files in examples/ir0"
   echo -e "\t-i run -O1 for given input\tex) -i simple.ir"
   exit 1 # Exit script after printing help
}

while getopts "i:ah" opt
do
   case "$opt" in
      i) run_one "$OPTARG";;
      a) run_folder examples/ir0;;
      ?) help_prompt;;
   esac
done

if (( $OPTIND == 1 )); then
  echo "$0: No arguments passed"
  help_prompt
fi

