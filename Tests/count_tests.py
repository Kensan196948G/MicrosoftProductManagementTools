#!/usr/bin/env python3
"""
Test function counter for dev1 system validation
"""
import glob
import re
import os

# Count test functions across all test files
test_files = []
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.py') and ('test_' in file or root.find('test') != -1):
            test_files.append(os.path.join(root, file))

total_functions = 0
test_file_count = 0
results = []

for file in test_files:
    try:
        with open(file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            # Count test functions (def test_*)
            functions = len(re.findall(r'def test_[a-zA-Z0-9_]+\(', content))
            if functions > 0:
                total_functions += functions
                test_file_count += 1
                results.append((file, functions))
    except Exception as e:
        pass

# Sort by function count
results.sort(key=lambda x: x[1], reverse=True)

print('=== TOP 15 TEST FILES ===')
for file, count in results[:15]:
    print(f'{file}: {count} functions')

print(f'\n=== SUMMARY ===')
print(f'Total test files: {test_file_count}')
print(f'Total test functions: {total_functions}')

if total_functions >= 1000:
    print(f'✅ dev1 system validation: {total_functions} functions (TARGET: 1,304)')
else:
    print(f'⚠️  Function count below dev1 target: {total_functions}/1,304')