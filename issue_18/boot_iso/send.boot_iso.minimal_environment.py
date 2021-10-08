#!/usr/bin/env python3

import requests

response = requests.post(
	"http://rpa.st/api/v1/paste",
	json={
		"expiry": "1hour",
		"files": [
			{
				"name": "boot_iso.minimal-environment.dnf.group.list.out",
				"lexer": "text",
				"content": "<all_the_file_content>"
			}
		]
	}
)

print(response.json())

