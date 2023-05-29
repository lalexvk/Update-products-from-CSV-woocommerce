#!/bin/bash

# Start of execution time
start_time=$(date +%s)

# Path to the CSV file
csv_file="..."

# SKUs to ignore
ignored_skus=("SKU" "sku2")

# WordPress username
username="..."

# Start message in the log
echo "Running the product update script..."

# SQL query to retrieve product information
sql_query="SELECT p.ID, p.post_status, pm.meta_value AS sku
           FROM wp_posts AS p
           JOIN wp_postmeta AS pm ON p.ID = pm.post_id
           WHERE p.post_type = 'product'
               AND pm.meta_key = '_sku';"

# Execute the SQL query using wp db query
results=$(wp db query "$sql_query" --skip-plugins --skip-themes --quiet --raw)

# Iterate over each line of the CSV file
	while IFS=';' read -r sku price stock || [[ -n "$sku" ]]; do
		sku=$(sed 's/"//g' <<< "$sku")
		price=$(sed 's/"//g' <<< "$price")
		stock=$(sed 's/"//g' <<< "$stock")

		# Check if SKU should be ignored
	if [[ " ${ignored_skus[@]} " =~ " $sku " ]]; then
		echo "Ignoring SKU: $sku"
		continue
	fi

	# Find the product in the query results
	product_info=$(grep -m 1 -e "$sku" <<< "$results")
	# Get the product ID and status
	product_id=$(echo "$product_info" | awk '{print $1}')
	status=$(echo "$product_info" | awk '{print $2}')

	# Check if the product exists in WooCommerce
	if [ -z "$product_id" ]; then
		echo "Product with SKU: $sku does not exist in WooCommerce."
		continue
	fi

	# Check the status and stock of the product
	if [ "$status" = "publish" ] && [ "$(awk -v stock="$stock" 'BEGIN{ if (stock == 0.00) { print 1 } else { print 0 } }')" -eq 1 ]; then
		# Change the product to draft if it's published and the stock is 0
		wp db query "UPDATE wp_posts SET post_status = 'draft' WHERE ID = $product_id;" --skip-plugins --skip-themes --quiet
		echo "Product SKU: $sku changed to draft."
	elif [ "$status" != "publish" ] && [ "$(awk -v stock="$stock" 'BEGIN{ if (stock == 0.00) { print 1 } else { print 0 } }')" -eq 0 ]; then
		# Publish the product if it's not published and the stock is not 0
		wp db query "UPDATE wp_posts SET post_status = 'publish' WHERE ID = $product_id;" --skip-plugins --skip-themes --quiet
		echo "Product SKU: $sku published."
	fi

	# Update the price and stock of the product in WooCommerce
	wp db query "UPDATE wp_postmeta SET meta_value = '$price' WHERE post_id = $product_id AND meta_key IN ('_regular_price', '_price');" --skip-plugins --skip-themes --quiet
	wp db query "UPDATE wp_postmeta SET meta_value = '$stock' WHERE post_id = $product_id AND meta_key = '_stock';" --skip-plugins --skip-themes --quiet
	echo "Product SKU: $sku updated with price: $price and stock: $stock"
done < "$csv_file"

# Completion message in the log
echo "
Product update script completed."
# End of execution time
end_time=$(date +%s)
execution_time=$((end_time - start_time))

# Print the execution time in seconds
echo "Execution time: $execution_time seconds."
