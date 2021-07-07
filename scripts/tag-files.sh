#! /bin/sh
# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

#TODO: add specific files without extensions

if [ $# -eq 0 ]
    then
    echo "Usage: $0 DirectoryToTag"
    exit 1
fi

start_path=$(pwd)
cd $1

#Ascii files
echo "Tagging files for ISO8859-1"

find . \( \
-name "*.1" -o \
-name "AUTHORS" -o \
-name ".babelrc" -o \
-name ".BABELRC" -o \
-name "*.bat" -o \
-name "*.BAT" -o \
-name "*.bnf" -o \
-name "*.BNF" -o \
-name "*.bsd" -o \
-name "*.BSD" -o \
-name "*.cer" -o \
-name "*.CER" -o \
-name "CODEOWNERS" -o \
-name "*.coffee" -o \
-name "*.COFFEE" -o \
-name "*.conf" -o \
-name "*.CONF" -o \
-name "*.def" -o \
-name "*.DEF" -o \
-name ".editorconfig" -o \
-name ".EDITORCONFIG" -o \
-name "*.el" -o \
-name "*.EL" -o \
-name ".eslintignore" -o \
-name ".ESLINTIGNORE" -o \
-name ".eslintrc" -o \
-name ".ESLINTRC" -o \
-name "*.gradle" -o \
-name "*.GRADLE" -o \
-name "*.in" -o \
-name "*.IN" -o \
-name "*.info" -o \
-name "*.INFO" -o \
-name "*.js" -o \
-name "*.JS" -o \
-name "Jenkinsfile" -o \
-name ".jscsrc" -o \
-name ".JSCSRC" -o \
-name ".jshintignore" -o \
-name ".JSHINTIGNORE" -o \
-name ".jshintrc" -o \
-name ".JSHINTRC" -o \
-name "*.json" -o \
-name "*.json.tpl" -o \
-name "*.json.template" -o \
-name "*.JSON" -o \
-name "*.jst" -o \
-name "*.JST" -o \
-name "*.key" -o \
-name "*.KEY" -o \
-name "LICENSE" -o \
-name "*.lock" -o \
-name "*.LOCK" -o \
-name "*.log" -o \
-name "*.LOG" -o \
-name "*.ls" -o \
-name "*.LS" -o \
-name ".mailmap" -o \
-name ".MAILMAP" -o \
-name "Makefile" -o \
-name "*.map" -o \
-name "*.MAP" -o \
-name "*.markdown" -o \
-name "*.MARKDOWN" -o \
-name "*.md" -o \
-name "*.MD" -o \
-name ".npmignore" -o \
-name ".NPMIGNORE" -o \
-name ".nycrc" -o \
-name ".NYCRC" -o \
-name "*.opts" -o \
-name "*.OPTS" -o \
-name "*.patch" -o \
-name "*.PATCH" -o \
-name "*.ppf" -o \
-name "*.PPF" -o \
-name "*.properties" -o \
-name "*.PROPERTIES" -o \
-name "README" -o \
-name "*.targ" -o \
-name "*.TARG" -o \
-name ".tm_properties" -o \
-name ".TM_PROPERTIES" -o \
-name "*.ts" -o \
-name "*.TS" -o \
-name "*.tst" -o \
-name "*.TST" -o \
-name "*.txt" -o \
-name "*.TXT" -o \
-name "*.xml" -o \
-name "*.XML" -o \
-name "*.yaml" -o \
-name "*.yaml.tpl" -o \
-name "*.yaml.template" -o \
-name "*.YAML" -o \
-name "*.yml" -o \
-name "*.yml.tpl" -o \
-name "*.yml.template" -o \
-name "*.YML" \
\) -exec chtag -tc ISO8859-1 {} \;

#UTF-8 files
#UTF-8 does not convert well, Best to leave these as binary instead.
echo "Tagging files for UTF-8 as binary"

find . \( \
-name "*.css" -o \
-name "*.CSS" -o \
-name "*.jsx" -o \
-name "*.JSX" -o \
-name "*.html" -o \
-name "*.HTML" -o \
-name "*.tsx" -o \
-name "*.TSX" -o \
-name "*.xlf" -o \
-name "*.XLF" \
\) -exec chtag -b {} \;

#Binary files
echo "Tagging files for binary"

find . \( \
-name "*.br" -o \
-name "*.BR" -o \
-name "*.bz2" -o \
-name "*.BZ2" -o \
-name "*.crx" -o \
-name "*.CRX" -o \
-name "*.eot" -o \
-name "*.EOT" -o \
-name "*.gif" -o \
-name "*.GIF" -o \
-name "*.gz" -o \
-name "*.GZ" -o \
-name "*.tgz" -o \
-name "*.TGZ" -o \
-name "*.jar" -o \
-name "*.JAR" -o \
-name "*.jpg" -o \
-name "*.JPG" -o \
-name "*.mpg" -o \
-name "*.MPG" -o \
-name "*.mp3" -o \
-name "*.MP3" -o \
-name "*.mp4" -o \
-name "*.MP4" -o \
-name "*.m4a" -o \
-name "*.M4A" -o \
-name "*.m4v" -o \
-name "*.M4V" -o \
-name "*.ogg" -o \
-name "*.OGG" -o \
-name "*.ogm" -o \
-name "*.OGM" -o \
-name "*.pax" -o \
-name "*.PAX" -o \
-name "*.p12" -o \
-name "*.P12" -o \
-name "*.pdf" -o \
-name "*.PDF" -o \
-name "*.png" -o \
-name "*.PNG" -o \
-name "*.svg" -o \
-name "*.SVG" -o \
-name "*.ttf" -o \
-name "*.TTF" -o \
-name "*.woff" -o \
-name "*.WOFF" -o \
-name "*.woff2" -o \
-name "*.WOFF2" -o \
-name "zssServer" \
\) -exec chtag -b {} \;

#Convert to ebcdic
echo "Converting ebcdic files"

find . \( \
-name ".gitmodules" -o \
-name "*.jcl" -o \
-name "*.JCL" -o \
-name "*.env" -o \
-name "*.ENV" -o \
-name "*.sh" -o \
-name "*.SH" \
\) -exec sh -c 'iconv -f iso8859-1 -t 1047 "$0" > "$0".1047' {} \; -exec sh -c 'mv "$0".1047 "$0"' {} \;

#Ebcdic files
echo "Tagging files for IBM-1047"

find . \( \
-name ".gitmodules" -o \
-name "*.jcl" -o \
-name "*.JCL" -o \
-name "*.sh" -o \
-name "*.SH" \
\) -exec chtag -tc 1047 {} \;

echo "Marking scripts as executable"
find . \( \
-name "*.sh" -o \
-name "*.SH" \
\) -exec chmod +x {} \;

cd $start_path
