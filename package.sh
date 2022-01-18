#!/bin/sh
version="$(grep addon.version ./addons/statustimers/statustimers.lua | head -n1 | cut -d\' -f2)"

find addons -maxdepth 3 -name '.DS_Store' -or -name '._*' > exclude.lst
find addons/statustimers/themes -mindepth 1 -maxdepth 1 -type d -not -name README.md -exec echo '{}/' ';' >> exclude.lst
find addons/statustimers/themes -mindepth 2 >> exclude.lst

rm -f "statustimers_v${version}.zip"
 zip -qq -r "statustimers_v${version}.zip" addons -x@exclude.lst -X
unzip -l "statustimers_v${version}.zip"

rm -f exclude.lst

