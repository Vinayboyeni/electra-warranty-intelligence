import json
import os
import glob

def load_json_robust(path):
    # Try different encodings
    encodings = ['utf-8', 'utf-16', 'utf-16-le', 'utf-16-be', 'latin-1']
    for enc in encodings:
        try:
            with open(path, 'r', encoding=enc) as f:
                return json.load(f)
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
    raise Exception("Could not decode JSON file")

# Load org fields
org_data = load_json_robust('c:/Users/vinay/Downloads/Warrenty Claim agent/scripts/org_custom_fields.json')

org_fields = set()
if 'result' in org_data:
    for item in org_data['result']:
        org_fields.add(item['fullName'])

# Find local fields
local_fields_paths = glob.glob('c:/Users/vinay/Downloads/Warrenty Claim agent/force-app/main/default/objects/*/fields/*.field-meta.xml')
matches = []

print("Comparing local fields with org fields...")

# We will also create a list of files to exclude
exclude_list = []

for path in local_fields_paths:
    parts = path.replace('\\', '/').split('/')
    obj_name = parts[-3]
    field_file = parts[-1]
    field_name = field_file.replace('.field-meta.xml', '')
    
    full_name = f"{obj_name}.{field_name}"
    
    if full_name in org_fields:
        matches.append(full_name)
        exclude_list.append(path)
        print(f"ALREADY IN ORG: {full_name}")

if not matches:
    print("No matching fields found between local and org.")
else:
    print(f"\nTotal matches found: {len(matches)}")
    print("\nPROPOSED EXCLUSIONS (for .forceignore):")
    for field in matches:
        print(field)

# Also check for picklist values in Claim.Status
# This is harder via CustomField listing if it's a standard field.
# We'd normally need to call sf org list metadata -m StandardValueSet -n CaseStatus or similar, 
# but Claim Status is often just a field on Claim.
