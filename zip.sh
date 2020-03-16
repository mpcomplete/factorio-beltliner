#!/bin/sh
name=Quickbelt_1.0.0
mkdir $name
cp -a * $name
rm $name/*.sh $name/*.zip $name/$name -rf
rm -rf ${name}.zip
zip ${name}.zip $name -r
rm -rf $name
