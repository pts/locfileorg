# locfileorg: local file organizer with tags on the command line

locfileorg lets you add tags to your files and then search for filenames matching the tags you specify. You can use it on the command line or from Midnight Commander. Extending the user interface of image viewers with tagging is planned. Currently locfileorg runs on Linux and macOS. The import/export feature makes it easy to integrate with other tagging and metadata solutions, and also to make and restore backups.

locfileorg is currently work-in-progress. The `*lfo* command-line tool, the corresponding Midnight Commander configuration and the user guide will be released soon.

To use locfileorg, you need:

* A supported operating system, currently Linux or macOS. There are no plans to support Windows directly (but it's possible if there is high demand). It seems easy to port to FreeBSD, NetBSD, Solaris-derivatives and AIX, but currently there are no active efforts.

* A fileystem which supports [extended attributes](https://en.wikipedia.org/wiki/Extended_file_attributes). On Linux, the most common filesystems (ext2, ext3, ext4, XFS, JFS, ReiserFS) are known to work, on macOS both HFS+ and APFS work, on Windows NTFS will work (using [alternate data streams](https://blog.malwarebytes.com/101/2015/07/introduction-to-alternate-data-streams/)). In the future, support may be added for any filesystem (including FAT, VFAT, FAT32 and exFAT) using [descript.ion](https://stackoverflow.com/q/1810398) files.

* On Linux, the filesystem has to be mounted with the *user_xattr* option. Doing so needs *root* privileges once.

* Familiarity with the command line or Midnight Commander.

locfileorg is leightweight and flexible:

* You can try it even without installing it.

* All the software and libraries it needs are either included or are part of the operating system. In 2 minutes you can start using it.

* It supports many storage devices and mounted filesystems at the same time.

* You can disconnect some storage devices, and locfileorgg will continue working with the rest. (However, files on disconnected devices will most likely be omitted from search results.)

* On a modern personal computer, it scales up to 10 million files, 1 million files with tags, 10 000 directories. It can process all these files and directories in a single command.

* It works on both hard drives (HDDs) and SSDs. It's much faster on SSDs.

locfileorg uses or works with the following technologies:

* [filesystem extended attributes](https://en.wikipedia.org/wiki/Extended_file_attributes) (primary storage for tags)

* [Perl](https://www.perl.org/) programming language (language the command-line tool is written in)

* [SQLite FTS4](https://www.sqlite.org/fts3.html) full-text index (for fast searching by tag)

* [Midnight Commander](https://midnight-commander.org/) text-mode visual file manager (convenient selection of files to be tagged)

* Bash, Zsh and other interactive shell (tagging up to millions of files with a single command)
