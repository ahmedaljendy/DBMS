display_table() {
    local lines=("$@")
    local widths=()
    local columns
    
    IFS=',' read -ra headers <<< "${lines[0]}"
    columns=${#headers[@]}
    
    for ((i = 0; i < columns; i++)); do
        widths[i]=${#headers[i]}
    done

    for line in "${lines[@]}"; do
        IFS=',' read -ra fields <<< "$line"
        for ((i = 0; i < columns; i++)); do
            [[ ${#fields[i]} -gt ${widths[i]} ]] && widths[i]=${#fields[i]}
        done
    done

    print_separator() {
        echo -n "+"
        for w in "${widths[@]}"; do
            printf '%s' "$(printf '%.0s-' $(seq 1 $((w + 2))))"
            echo -n "+"
        done
        echo
    }

    print_separator
    for i in "${!lines[@]}"; do
        IFS=',' read -ra fields <<< "${lines[i]}"
        echo -n "|"
        for ((j = 0; j < columns; j++)); do
            printf " %-*s |" "${widths[j]}" "${fields[j]}"
        done
        echo
        [[ $i -eq 0 ]] && print_separator
    done
    print_separator 
}


list_tables() {
    echo "Available Tables:"
    ls "$DB_DIR/$CURRENT_DB" | grep ".metadata$" | sed 's/.metadata$//' | awk '{print NR".", $0}'
}