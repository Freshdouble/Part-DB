#!/bin/bash

UPS='/dev/stdout'

cd "../" # base directory of Part-DB

tab2spaces () # replaces tabs with spaces (*.php and *.tmpl)
{
    echo -e "- replacing tabs with spaces"

    FILES=`find . -type f -name "*php" -o -name "*tmpl" -o -path "./development" -prune -o -path "./documentation" -prune`
    for FILE in $FILES
    do
        echo "working on file $FILE..."
        expand -t4 "$FILE" > "$FILE.bak"
        sed 's/^ *$//g' "$FILE.bak" > "$FILE"
        rm -f "$FILE.bak"
    done
}

remove_backups () # remove backup files from working directory ( Files with ~ )
{
    echo -e "- removing backup files..."
    find . -name "*~" -print -exec rm {} \;
}

svn_modified ()
{
    MODIFIED=`svn status | sed 's/ \+/@/g'`
    for MOD in $MODIFIED
    do
        STATUS=`echo $MOD | cut -d"@" -f1`
        FILE=`echo $MOD | cut -d"@" -f2`
        case $STATUS in
            M|A)
                echo -e "copy :: $FILE `sha256sum $FILE| cut -d" " -f1`" 1>> $UPS
                echo -e "chmod :: `stat -c "%n 0%a" $FILE`" 1>> $UPS
                ;;
            R|D)
                echo -e "delete :: $FILE" 1>> $UPS
                ;;
            *)
                echo -e "log :: $FILE unknown status" 1>> $UPS
                ;;
        esac
	done
}

svn_all ()
{
    find . -name "*~" -exec rm {} \;
    FILES=`find . | grep -v ".svn" | sed 's/^.\///g'`
    for FILE in $FILES
    do
        if [ $FILE != '.' -a $FILE != '..' ]; then
            stat -c "chmod :: %n 0%a" $FILE 1>> $UPS
        fi
    done
}

doxygen_build () # create / update the doxygen documentation
{
    echo -e "- creating/updating doxygen documentatuion..."
    cd "development/doxygen/"
    doxygen "Doxyfile"
    cd "../../"
}

build_install_package () # create a *.tar.gz        TODO: this function is not really pretty, we should make it better
{
    # line with version number in config_defaults.php:
    # $config['system']['version']                            = '0.3.0.RC1';  // examples: '0.2.2' or '0.2.2.RC2' (see class.SystemVersion.php)
    
    # get the Part-DB version, like "0.3.0.RC1"
    VERSION=$(grep -E "config\['system'\]\['version'\]\s*=\s*'" config_defaults.php | cut -d\' -f6)
    
    echo -e "- build install package for Part-DB $VERSION..."
    
    #clean up output directory
    rm -f development/package_output/Part-DB_*
    chmod -R 777 development/package_output/files/ # we need permissions to delete this folder
    rm -f -r development/package_output/files/
    mkdir development/package_output/files/
    
    # copy all needed files to development/package_output/files/
    .htaccess????
    find . -not \(      -path "./.svn*" \
                    -o  -path "./development*" \
                    -o  -path "./documentation/dokuwiki/data/cache*" \
                    -o  -path "./documentation/dokuwiki/data/tmp*" \
                    -o  \(          -path "./data*" \
                            -a -not -path "./data/backup" \
                            -a -not -path "./data/media" \
                            -a -not -path "./data/log" \
                            -a -not -name "index.html" \
                            -a -not -name ".htaccess" \
                        \) \
                \) > "development/package_output/filelist.txt"

    cd "development/package_output/files/"
    
    # set file permissions correct for using Part-DB
    #find * -type d -print0 | xargs -0 chmod 555
    #find * -type f -print0 | xargs -0 chmod 444
    #find data/ -type d -print0 | xargs -0 chmod 755
    #find data/ -type f -print0 | xargs -0 chmod 644
    
    # create *.tar.gz
    #tar -czvf "development/package_output/Part-DB_$VERSION.tar.gz" -T "development/package_output/filelist.txt" --no-recursion --owner=www-data --group=www-data
    #tar -czvf "../Part-DB_$VERSION.tar.gz" * --owner=www-data --group=www-data
    
    cd "../../../"
}

while [ "$1" != "" ]; do
    case $1 in
        -o)
            shift
            UPS=$1
            echo -e "creating $UPS..."
            ;;
        -t|--tab)
            tab2spaces
            ;;
        -p|--pack)
            #remove_backups
            #tab2spaces
            build_install_package
            ;;
        -d|--doxygen)
            doxygen_build
            ;;
        -a|--add)
            remove_backups
            echo -e "- adding files to repository..."
            svn add * --force
            ;;
        -r|--remove)
            remove_backups
            ;;
        -c|--commit)
            shift
            echo -e "- committing..."
            svn commit -m "$1"
            svn up
            ;;
        --all)
            remove_backups
            tab2spaces
            doxygen_build
            echo -e "- adding files to repository..."
            svn add * --force
            echo -e "- committing..."
            shift
            svn commit -m "$1"
            svn up
            ;;
        --ups)
            shift
            case $1 in
                all)
                    svn_all
                    ;;
                update)
                    svn_modified
                    ;;
            esac
            ;;
        *)
            echo "$0"
            echo -e "Licence: GPL, 2012 by Udo Neist\n"
            echo "Usage: $0"
            echo -e "\nWrapper for svn"
            echo -e "\nHint: Use code.google.com only with https to avoid problems with authentication!"
            echo -e "\n\t-t|--tab\t\tReplace 1 tab with 4 spaces."
            echo -e "\t-d|--doxygen\t\tUpdate the doxygen documentation."
            echo -e "\t-r|--remove\t\tRemove backup files."
            echo -e "\t-a|--add\t\tRemove backup files and add new files to repository."
            echo -e "\t-c|--commit text\tCommit with comment."
            echo -e "\t--all text\t\tAll steps above in one."
            echo -e "\nMaking an UPS-script for scripted update (default hash: sha256)"
            echo -e "\n\t-o\t\t\tRedirects output to the specified file. Attention! File will be overwritten!"
            echo -e "\n\t--ups update\t\tShow svn status of each modified file/directory and create an ups-script (e.g. update.ups)"
            echo -e "\t--ups all\t\tShow status of all files/directories and create an ups-script (e.g. repair.ups)"
            exit 1
            ;;
    esac
    shift
done