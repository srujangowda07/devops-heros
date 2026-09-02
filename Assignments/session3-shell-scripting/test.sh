#!/bin/bash

mkdir res_log
cd res_log

current_date=$(date)
hostname=$(hostname)
username=$(whoami)

echo "Current Date: $current_date"
echo "Hostname: $hostname"
echo "Username: $username"

echo "Disk Usage:"
df -h

touch process.log
ps > process.log

read -p "Enter your name: " name
read -p "Enter your roll number: " roll_no
read -p "Enter your comment: " comment

echo "Name: $name"
echo "Roll Number: $roll_no"
echo "Comment: $comment"

echo "My name is $name and comment is $comment and date is $current_date" > result.log