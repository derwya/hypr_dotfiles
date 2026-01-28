#!/bin/bash

hyprctl devices -j | jq -r '.keyboards[].name' | while read -r name; do
    hyprctl switchxkblayout "$name" next
done
