list_tables() {
    echo "Available Tables:"
    ls "$DB_DIR/$CURRENT_DB" | grep ".metadata$" | sed 's/.metadata$//' | awk '{print NR".", $0}'
}

create_table() {
    read -ep "Enter table name: " tblname
    tblname=$(removeQuotes "$tblname")
    if ! validate_identifier "$tblname"; then return; fi
    local metadata="$DB_DIR/$CURRENT_DB/$tblname.metadata"
    local datafile="$DB_DIR/$CURRENT_DB/$tblname.data"

    if [[ -f $metadata ]]; then
        echo "Table '$tblname' already exists!"
        return
    fi

    echo "Define columns (format: column_name data_type [primary]):"
    echo "Enter 'done' when finished"
    declare -a columns
    local has_primary=false
    declare -a column_names
    while true; do
        read -ep "Column definition: " col_name col_type col_primary
        if [[ -z $col_primary ]]; then
            col_def=$(echo "$col_name $col_type" | tr '[A-Z]' '[a-z]')
        else
            col_def=$(echo "$col_name $col_type $col_primary" | tr '[A-Z]' '[a-z]')
        fi

        if [[ $(echo $col_def | tr -d ' ') == 'done' ]]; then
            break
        fi

        if ! validate_column_def "$col_def"; then
            echo "Invalid definition! Use: name type [primary]"
            continue
        fi

        if [[ $col_def =~ primary$ ]]; then
            if $has_primary; then
                echo "Primary key already defined!"
                continue
            fi
            has_primary=true
        fi
        columns+=("$col_def")
        column_names+=("$col_name")
    done
    printf "%s\n" "${columns[@]}" >"$metadata"
    touch "$datafile"
    echo "${column_names[@]}" | tr ' ' ',' >"$datafile"
    echo "Table '$tblname' created."
}

drop_table() {
    read -ep "Enter table name: " tblname
    local metadata="$DB_DIR/$CURRENT_DB/$tblname.metadata"
    local datafile="$DB_DIR/$CURRENT_DB/$tblname.data"

    if [[ ! -f $metadata ]]; then
        echo "Table '$tblname' does not exist!"
        return
    fi

    rm "$metadata" "$datafile"
    echo "Table '$tblname' dropped."
}

insert_row() {
    read -ep "Enter table name: " tblname
    local metadata="$DB_DIR/$CURRENT_DB/$tblname.metadata"
    local datafile="$DB_DIR/$CURRENT_DB/$tblname.data"

    if [[ ! -f "$metadata" ]]; then
        echo "Table '$tblname' does not exist!"
        return
    fi

    declare -a values
    columns=()

    while IFS='\n' read -r col; do
        columns+=("$col")
    done <"$metadata"

    for index in "${!columns[@]}"; do
        local col=${columns[$index]}
        local col_name=$(echo $col | awk '{print $1}')
        local col_type=$(echo $col | awk '{print $2}')
        local is_primary=$(echo $col | awk '{print $3=="primary"}')
        while true; do
            read -ep "Enter value for $col_name ($col_type): " value
            if ! validate_data_type "$value" "$col_type"; then
                echo "Invalid $col_type value!"
                continue
            fi
            let ind=index+1
            if [[ $is_primary -eq 1 ]] && [[ -z $value ]]; then
                echo "Primary key cannot be empty!"
                continue
            fi
            if [[ $is_primary -eq 1 ]] && check_pk_exists "$tblname" "$value" $ind; then
                echo "Primary key $value already exists!"
                continue
            fi
            values+=("$value")
            break
        done
    done

    row=""
    for index in "${!values[@]}"; do
        if [[ $index -eq 0 ]]; then
            row="${values[$index]}"
        else
            row="$row,${values[$index]}"
        fi
    done
    echo "$row" >>"$datafile"
    echo "Row inserted."
}

select_from_table() {
    declare -a conditions
    local row="" 
    if [[ -z $1 ]]; then
        declare -a col_names
        read -ep "Enter table name: " tblname
        local datafile="$DB_DIR/$CURRENT_DB/$tblname.data"
        local metafile="$DB_DIR/$CURRENT_DB/$tblname.metadata"

        if [[ ! -f $datafile ]]; then
            echo "Table '$tblname' does not exist!"
            return
        fi

        read -ep "Enter conditions in form "col=value" and separated by ',' or type 'all' to get all data : " line
        if [[ $line != "all" ]] && ! [[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*=[^,]+)(,[a-zA-Z_][a-zA-Z0-9_]*=[^,]+)*$ ]]; then
            echo "Invalid conditions format!"
            return
        fi

        IFS=',' read -r -a conditions <<<"$line"
    else
        local datafile="$DB_DIR/$CURRENT_DB/$1.data"
        local metafile="$DB_DIR/$CURRENT_DB/$1.metadata"
        line=$2
        if [[ $line != "all" ]] && ! [[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*=[^,]+)(,[a-zA-Z_][a-zA-Z0-9_]*=[^,]+)*$ ]]; then
            echo "Invalid conditions format!"
            return
        fi
        IFS=',' read -r -a conditions <<<"$line"
    fi
    row=$(awk -F ',' 'NR == 1 {print $0}' "$datafile") 
    filter_cmd="1"
    if [[ ${conditions[0]} == "all" ]]; then
        mapfile -t data_array < "$datafile"
        display_table "${data_array[@]}"
        return
    fi
    for condition in "${conditions[@]}"; do
        column_name=$(echo "$condition" | cut -d'=' -f1)
        column_value=$(echo "$condition" | cut -d'=' -f2)
        col_index=$(awk -v col="$column_name" '$1 == col {print NR}' "$metafile")
        if [[ -z "$col_index" ]]; then
            echo "Column '$column_name' not found in metadata!"
            return
        fi
        filter_cmd="$filter_cmd && \$${col_index} == \"$column_value\""
    done
    result=("$row")
    result+=($(awk -F',' "$filter_cmd" "$datafile"))

    

    display_table "${result[@]}"
    # cat <<<"$result"
}

delete_from_table() {
    read -ep "Enter table name: " table_name
    local datafile="$DB_DIR/$CURRENT_DB/$table_name.data"
    local metafile="$DB_DIR/$CURRENT_DB/$table_name.metadata"
    if ! [[ -f $datafile ]]; then
        echo "Table '$table_name' does not exist!"
        return
    fi

    columns=$(cat $metafile | cut -d' ' -f1)
    read -ep $'Enter delete conditions in format colname=value separated by "," or type 'all' to get all data : ' conditions
    IFS=' ' read -a lines <<<$(echo $(select_from_table "$table_name" "$conditions"))
    for index in ${!lines[@]}; do
        if [[ $index -eq 0 ]] && [[ $conditions == "all" ]]; then
            continue
        fi
        sed -i "/${lines[index]}/d" $datafile
    done
    return 1
}

update_table() {
    read -ep "Enter table name:" table_name
    local datafile="$DB_DIR/$CURRENT_DB/$table_name.data"
    local metafile="$DB_DIR/$CURRENT_DB/$table_name.metadata"

    if [[ ! -f "$datafile" ]]; then
        echo "Table '$table_name' doesn't exist"
        return 1
    fi

    columns=$(cat $metafile | cut -d' ' -f1)
    read -ep 'Enter update conditions in format colname=value separated by "," or type 'all' to get all data : ' conditions
    IFS=' ' read -a lines <<<$(echo $(select_from_table "$table_name" "$conditions"))

    if [[ -z "$lines" ]]; then
        echo "No rows found!"
        return 1
    fi

    read -ep "Column Name: " column
    read -ep "New value: " value

    if ! grep -q "$column" $metafile; then
        echo "Column '$column' not found in metadata!"
        return 1
    fi
    col_index=$(awk -v col="$column" '$1 == col {print NR}' "$metafile")
    count=0
    for line in "${lines[@]}"; do
        ((count++))
    done
    if [[ $count -gt 1 ]] && [[ -n $(awk -v col="$column" -v col_ind="$col_index" '$1 == col && $3 == "primary" {print 0}' "$metafile") ]]; then
    echo "primary key cant be repeated"
    return
    elif [[ $count -eq 1 ]] && [[ -n $(awk -v col="$column" -v col_ind="$col_index" '$1 == col && $3 == "primary" {print 0}' "$metafile") ]]; then
        if [[ -n $(awk -F',' -v idx="$col_index" -v val="$value" '$idx == val {print 1}' "$datafile") ]] ;then
        echo "primary key cant be repeated"
        return
        fi
    fi
    
    declare -a updated_lines
    for line in "${lines[@]}"; do
        updated_line=$(echo $line | awk -v col_index="$col_index" -v value="$value" -F',' -v OFS=',' '{$col_index=value; print}')
        updated_lines+=("$updated_line")
    done

    for index in ${!lines[@]}; do
        if [[ $index -eq 0 ]] && [[ $conditions == "all" ]]; then
            continue
        fi
        sed -i "s/^${lines[index]}$/${updated_lines[index]}/" "$datafile"
    done
    echo "Update successfull!"
}
