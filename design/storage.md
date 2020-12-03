# Where and how should tags be stored?

## Requirements

The primary location where tags are store should fulfill these requirements:

* QUICKTAG: Adding and removing tags on a single file is fast.

* QUICKSHOW: Showing the tags a single file is fast.

* QUICKSEARCH: Listing all files matching the specified query (e.g. having all specified tags) is fast. It should scale for a local filesystem with 10 million files, 1 million files with tags, 10 000 directories. In many cases below a search is done by a sequential scan of all (or many) files, which is way too slow, especially on a HDD. To improve this, an index can be introduced: searching in the index is faster, but the index may be stale, and updating the index may take a long time (i.e. several hours). See in the section below for index options.

* QUICKDATA: File and directory operations unrelated to tags (e.g. listing the contents of a large directory; computing an SHA-256 checksum of a large file) are just as fast as if tagging wasn't used at all.

* COPY: When a file is copied, its tags are also copied.

* MOVE: When a file is renamed or moved (or one of the parent directories of the file is renamed or moved), the tags the file has are retained.

* OTHERFS: When a file is copied or moved to another filesystem, the tags the file has are retained.

* EDIT: When a file is saved in an editor, the tags the file has are retained.

* QUICKEXPORT: Exporting filename--tags pairs of many files to a backup file is fast.

* QUICKIMPORT: Importing filename--tags pairs of many files from a backup file is fast.

Since there are many tradeoffs, it is expected that each storage option will only partially fulfill the requirements.

In most storage systems (such as databases with [ACID guarantees](https://en.wikipedia.org/wiki/ACID)) it's rare to lose data, but in case of local file tagging, filesystem operations are an additional source of data loss (which needs to be prevented). E.g. if the storage system stores a list of filename--tags pairs, and after a file or one of its parent directories has been renamed or moved, the stored filename has to be updated to the new one. Without that update, the tags for that file (as accessed by its new filename) are lost, and by this time it looks impossible to figure out which dangling tags stored belong to which files.

## Storage options

### File descriptions (descript.ion)

* Tags are stored in a file named descript.ion in each directory. Each line of this file looks like `"filename" description` (quotes are optional if the filename doesn't contain whitespace).

* This descript.ion file format was introduced by 4DOS, and it's supported by some modern file management tools:

  * Total Commander (Windows only): Use Ctrl-*Z* to edit descriptions. For COPY and MOVE, enable, *Configuration / Options / Operation / on the bottom at File comments / Copy comments with files*. However, it will never overwrite existing comments, practically omitting the copy.

  * Double Commander (cross-platform including Windows, macOS and Linux): Enable *File operations / Process comments with files/folders*.

* Some image viewers such as ACDSee and XnView can display comments found in descript.ion files.

* The file format doesn't support filenames with space and " in them.

* Some syntax can be introduced so that only some parts of file descriptions will be treated as tags.

* It will work with all filesystems and all usual operating systems.

* Requirements:

  * QUICKTAG: The descript.ion file has to be rewritten. This is relatively fast for directories with <10000 files. Use mandatory locking to prevent concurrent access.

  * QUICKSHOW: Relatively fast (sequential scan over a text file with simple parsing) for directories with <10000 files.

  * QUICKSEARCH: Search is quite slow without an index, because it requires a sequential scan of each directory and a sequential read of all descript.ion files). Using an index (see below) will improve this.

  * QUICKDATA: OK.

  * COPY: Only OK if the few specific file management tools are used. Linux command-line tools (e.g. cp, rsync) and Midnight Commander (mc) can't do it.

  * MOVE: Same as COPY.

  * OTHERFS: Moving over filesystem boundaries doesn't cause extra problems. (The problems of COPY also apply here.) All filesystems support descript.ion files.

  * EDIT: OK.

  * QUICKEXPORT: OK.

  * QUICKIMPORT: OK. A bit slower if there are many existing files with descriptions in the destination directory.

### Content management system with FUSE view

* All file access is done through an API to a content management system (CMS), thus the CMS can keep an up-to-date, indexed (fast to query) database of file data and metadata (including tags). For easy access local programs (including image viewers, video players and word processors), a virtual filesystem is exposed using [FUSE](https://en.wikipedia.org/wiki/Filesystem_in_Userspace).

* Because of the FUSE dependency, this will work on Linux, macOS, FreeBSD, OpenBSD and NetBSD etc., but it won't work on Windows.

* Very few CMSes provide a FUSE view, but that one could be implemented using the API the CMS already provides. However, modifying existing files can be hard to implement, because most CMSes don't have an API with open-for-write, write-chunk, close calls, and that's what local programs want and what FUSE provides.

* To overcome the read-only and other limitations, it's possible to design and implement a new, custom CMS just for tagging. The simplest such CMS is the direct CMS, which uses a local filesystem (with the identity mapping for pathnames) for file storage and maybe some indexed database (e.g. SQLite with [FTS4](https://www.sqlite.org/fts3.html) full-text index) for the tags. One important reason why the local filesystem shouldn't be used directly by programs, but through FUSE is that FUSE backend program updates the pathnames in the tag database upon each MOVE operation.

* Existing CMS APIs tend to be slow for everyday use (as a replacement for direct access to the local filesystem), and this is likely to hinder significant user adoption. The primary reason for the slowness is network serialization overhead. Also FUSE makes regular filesystem caching less effective on Linux, thus making it slower. Even the direct CMS above (the fastest possible) can be too slow because of the FUSE overhead, especially if a scripting language (rather than e.g. C, C++ or Go) is used to implement the FUSE handler. In an informal speed test, listing (ls -l) on a directory containing 3000 files, on a HDD took 15 seconds with FUSE (direct CMS), and 5 seconds on the local filesystem.

* [movemetafs](https://github.com/pts/movemetafs) is an old implementation of the direct CMS in Perl, implementing a FUSE handler, using a MySQL database for storing filename--tags pairs and a *FULLTEXT* index on the field containing the space-separated list of tags a single file has. In case the local filesystem is modified directly, movemetafs runs a recursive filesystem watcher (using [rfsdelta](https://github.com/pts/rfsdelta) for Linux 2.6), and updates the database based on those local modifications. Please note that movemetafs is outdated (no significant changes since 2007-01), and it likely doesn't work on modern Linux systems. Please also note that updates based on the recursive filesystem watcher may have significant synchronization issues, and the kernel module in rfsdelta is quite unstable, causing kernel panics (crashes). Please also note that it's a significant maintenance burden to keep a kernel module up-to-date, because the source-level Linux kernel API changes very quickly.

* Requirements:

  * QUICKTAG: OK.

  * QUICKSHOW: OK.

  * QUICKSEARCH: OK. The database is always kept up to date, and a full-text index on the tags makes searching fast.

  * QUICKDATA: Can be significantly slower. File reads (e.g. computing an SHA-256 checksum) also become slower. Metadata reads (such as listing all files in a directory on an HDD) can become much (e.g. 3 times) slower. This will be a user-visible performance regression (compared to previous workflows without tagging), hindering user adaption.

  * COPY: Since most tools implement a file copy using the open-for-write, write-chunk, close calls, they won't copy the tags. To get the tags copied, the FUSE handler can expose the tags in [extended attributes](https://en.wikipedia.org/wiki/Extended_file_attributes), and it would work with copy tools which support extended attributes. (E.g. Linux `cp -a` and `rsync -aX` support it, but Midnight Commander doesn't, see more below). However, if the file is accidentally copied with a tool which doesn't support extended attributes, tags in the copy will be lost.

  * MOVE: OK. If one of the parent directories is renamed or moved, then all files need to be renamed in the CMS database, which may take a few seconds, but that is still tolerable, because such a move is rare.

  * OTHERFS: Same as COPY, provided that the destination filesystem also supports extended attributes.

  * EDIT: It works iff the editor saves the changes back to the original file (rather than creating a new file, and moving it over the the original file). There are many editors in both categories. As a workaround for editors which do renames, the FUSE handler can employ some heuristics to detect the rename-on-save situation, and then copy the tags over from the old file.

  * QUICKEXPORT: OK if the CMS API supports it. It's easy to implement it in a custom CMS, e.g. the direct CMS.

  * QUICKIMPORT: Same as QUICKEXPORT.

### Metadata fields within files

* Some file formats have comment and other metadata fields which can be used to store tags. To make this practically useful, the storage system has to understand dozens of file formats and a few metadata formats, all for read and write. Files of unsupported formats will not be able to receive tags.

* Some file formats can store the same metadata (e.g. title and author) in many different locations, thus the storage system has to update tags in all of those when modifying tags.

* This approach won't work if it's not allowed or not practical to modify files after they were created. For example, in a Git repository or on an IPFS filesystem files are accessed by their checksum, and changing tags would change the file, thus change the checksum, thus all references would have to be updated, and this cascade would be too complex or too slow.

* Another disadvantage: Many systems compare last-modification time and file size for checking that a file has been changed. It's possible to change the last-modification time back (but there will be a small time window with the wrong value), but in many cases it's not possible to keep the original file size (e.g. if lots of tags are added).

* Another disadvantage: Many transfer systems rely on checksums for checking that a file has been changed (or corrupted). Changing tags would trigger false alarms and would waste time and bandwidth for additional transfers. It's possible but typically not feasible to modify the checksum algorithm to ignore tags.

* Another disadvantage: Some users who share files with others prefer keeping the tags private by default. For them it would be inconvenient and wasteful (of local storage space) to make a copy of all files, remove the tags in the copy, share the modified copy, wait for the transfer, and only then remove the modified copy. A tag-stripping [FUSE](https://en.wikipedia.org/wiki/Filesystem_in_Userspace) filesystem could be used to automate all this.

* [XMP](https://en.wikipedia.org/wiki/Extensible_Metadata_Platform) is an XML-based metadata container with arbitrary metadata fields (some of them standardized). XMP is supported by many popular file formats, e.g. PDF, JPEG, GIF, PNG, HTML, MP3, MP4, AVI. It looks like a good candidate for storing tags. However, support for each file format has to be implemented and maintained separately.

* Other metadata containers: JPEG has comments and APP* markers, MP3 has ID3v2 tags and ofthers, HTML has the `<meta ...>` tag, MP4 has QuickTime metadata ([set it with ffmpeg](https://exiftool.org/forum/index.php?topic=9312.0) `-metadata`), archives (e.g. ZIP, RAR) have archive-level comments.

* Storing each file in a ZIP archive (without actual compression attempts in most cases, to save CPU time at both read and write time) and adding tags to the ZIP member comment (or to the ZIP archive comment) is also an option. As another benefit, this would make it hard to modify files accidentally (because most editors are not able to save changes to a ZIP archive member). As another bnefit, it would work by supporting parts of a single, simple file format (ZIP) only. However, most image viewers, media players and editors aren't able to find and extract members from ZIP files automatically, so to make this useful, all software used would have to be updated (quite infeasible), or a ZIP-stripping [FUSE](https://en.wikipedia.org/wiki/Filesystem_in_Userspace) filesystem could be written and used (feasible, but makes it inconvenient and slow for the user).

* Requirements:

  * QUICKTAG: It can be slow if many tags are added to a long file, and the entire long file has to be rewritten. Also files of some formats are complicated and error-prone to modify. This may make the file to become invalid (unloadable) after tagging.

  * QUICKSHOW: OK most of the time, but partially parsing the file to extract tags is slow for some formats.

  * QUICKSEARCH: Search is very slow on HDD without an index. Using an index (see below) will improve this.

  * QUICKDATA: OK. The additional bytes used by tags within the is usually negligible.

  * COPY: OK.

  * MOVE: OK.

  * OTHERFS: OK.

  * EDIT: It works iff the editor saves all metadata back. Many editors don't do this, but they just ignore all metadata they don't recognize when opening the file, and tags get lost at this point, and by the time the editor saves the file they have been long gone.

  * QUICKEXPORT: Exporting tags of lots of files is very slow, because each file has to be parsed.

  * QUICKIMPORT: Importing lots of tags is very slow, because each file has to be parsed and maybe rewritten.

### Extended attributes

* [Extended attributes](https://en.wikipedia.org/wiki/Extended_file_attributes) are a list of key--value string pairs attached to a file inode, thus they are kept when the file is renamed or moved within the filesystem. A key is introduced for tagging, and the corresponding value would be a space-separated list of tags the file has.

* Many filesystems on many operating systems support extended attributes:

  * On Linux: ext2, ext3 and ext4, ZFS, Btrfs, JFS, XFS, [NFSv4.2 on Linux >=5.9](https://stackoverflow.com/a/47805199) and some others. For ntfs with the ntfs-3g driver, after `mount ... -o streams_interface=xattr`, the extended attribute *user.X* maps to NTFS alternate data stream *X* . For ext2, ext3, ext4, reiserfs, reiser4 and cifs, `mount ... -o user_xattr` has to be specified (also works for remounting and already mounted filesystem) for modifying extended attributes as non-root.

  * On macOS: HFS+ (since Mac OS/X 10.4) and APFS.

  * On Windows: NTFS alternate data streams can be used as an alternative.

  * The most popular cross-platform (Linux, macOS, Windows) read-write filesystems (FAT, VFAT, FAT32 and exFAT) don't support extended attributes.

  * Some versions of the UDF filesystem, Linux, Windows) support extended attributes. It has to be checked whether they work on [macOS](http://www.manpagez.com/man/8/mount_udf/osx-10.5.php), Linux and Windows.

  * NFS (network filesystem typically used on Unix systems for both client and server): [NFSv4.2 on Linux >=5.9, since 2020-11](https://stackoverflow.com/a/47805199) supports extended attribute. Support by NFS clients and servers may get delayed.

  * [Samba](https://en.wikipedia.org/wiki/Samba_(software)) >= 3.0.10 (network file system server) supports extended attributes. On the Linux client, mount the share with `mount ... -t cifs -o user_xattr`. [This blog post](https://www.jankyrobotsecurity.com/2019/04/15/alternate-data-streams-redux/) indicates that macOS and Windows clients also support extended attributes.

* [fuse_xattrs](https://github.com/fbarriga/fuse_xattrs) can emulate extended attributes (by putting them to per-file sidecar files with the *.xattr* suffix). It also takes care of moving the sidecar file when needed. However, it's a bit inconvenient to do an extra *mount* operation.

* Search, when implemented using a sequential scan will be very slow, because it lists each directory and file, including 2 disk seeks for each file (1 for the inode and 1 for the extended attribute contining the tag, maybe 1 more for the list of extended attributes). To improve this, an index database can be built (see design details in descript.ion). This will move the sequantial scan from query time to index build time. On top of this, faster, incremental index updates are also possible if we can detect and skip subtrees which have been unchanged since the last index update. To do so, we can write and use a kernel module to bump the last-modification times of directories (all the way up to the filesystem root) upon each file tag change and rename. When updating the index database, a subtree is detected to be unchanged iff the last-modification time of its top directory is the same on the filesystem and in the index database. Even the incremental index updates can be very slow on an HDD with many large top directories (with >1000 files each), because disk seeks are needed to visit each file in those directories, even if only a single file has changed there since the last update. [rmtimeup](https://github.com/pts/ppfiletagger/tree/master/rmtimeup) implements such a kernel module, and [ppfiletagger](https://github.com/pts/ppfiletagger) implements index updates and query functionality in Python 2, using SQLite with [FTS3](https://www.sqlite.org/fts3.html) for the fulltext index.

* It sounds tempting to use a recursive filesystem watcher (instead of propagating the last-modification times up) to detect filesystem changes (i.e. extended attribute changes, file moves and directory moves). However, some operating systems (such as Linux) don't have recursive filesystem watchers (at least not those which scale up to 10 000 directories and 10 million files); and recursive filesystem watchers need a daemon process running for propagating changes to the index, and if the filesystem was modified while the daemon was (accidentally) not running, then a full filesystem scan is need to rebuild the index. Propagating the last-modification times up doesn't need a daemon, and it's concurrency and synchronization is less fragile (than of e.g. the recursive filesystem watcher getting events from the Linux kernel module [rmtimeup](https://github.com/pts/ppfiletagger/tree/master/rmtimeup)).

* Requirements:

  * QUICKTAG: OK.

  * QUICKSHOW: OK.

  * QUICKSEARCH: Search is very slow on HDD without an index. Using an index (see below) will improve this.

  * QUICKDATA: OK.

  * COPY: Only OK if the few specific file management tools are used. Linux command-line tools need flags (e.g. `cp -a`, `rsync -aX`, `mv` works by default), some macOS command-line tools work (`cp` and `mv` work by default, `rsync` on macOS old, it doesn't have the `-X` flag), Midnight Commander (mc) can't do it. Flags for command-line tools can be added as shell aliases to prevent them from being forgotten, but aliases are ignored in shell scripts and other programs.

  * MOVE: OK. However, it gives the user the false sense of security when doing a move in Midnight Commander (by pressing *F6*): tags are silently lost in the rare case when the destination is on a different filesystem.

  * OTHERFS: Same as COPY.

  * EDIT: It works iff the editor saves the changes back to the original file (rather than creating a new file, and moving it over the the original file). There are many editors in both categories. So tags will be lost at save time in many editors.

  * QUICKEXPORT: OK.

  * QUICKIMPORT: OK.

## Using an index to speed up searches

### Introduction to the index

The simplest and slowest way of doing search (i.e. listing all files matching the specified query (e.g. having all specified tags)) is doing a full export, parsing the export output file, doing a match on each tags string, and returning the filename if there was a match. The slowest of this is doing an export (which typically involves a sequential, recursive file and directory scan). Parsing the export output can be made fast by introducing a very simple export file format (such as each line containing `TAGS :: FILENAME`). Doing the match (filtering) can be made fast by parsing and optimizing the query first; then doing the match will involve a few string hash lookups for each tag.

The most important disadvantage of using an index for search is that stale results may be returned if the filesystem has changed since the last index update. (Updates are usually manual.)

A sequential, recursive file and directory scan typically becomes too slow for interactive use with 1000 files on HDD (dominated by the per-file seek times) or 50 000 files on SSD (caused by the limited SSD IOPS and the CPU time used). (The previous numbers were reasonable in 2020.) To run searches faster, we need a database (preferably one whose backing files keep the data together, thus making the seek count low) with an index (which reduces the amount of data to be read for each search from the entire backing file to small fraction of it).

Many database systems support full-text index on a string-valued table field. A full-text index creates and maintains auxilary data structures to make subset queries fast. For example, if the subset query is *(2020 AND NOT university) OR party* (syntax may vary depending on the type of the database), then a row will match if the string contains the word *2020* and it doesn't contain the word *university*, or it contains the word *party*. When the field is inserted or updated, the database system lowercases it, splits it to words (the details are configurable), and updates its auxilary data structures accordingly. Later it executes a subset query by parsing it and making a plan how to read (parts of the) auxiliary data structures. The [inverted index](https://en.wikipedia.org/wiki/Inverted_index) (see also this [article describing Google web search](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/37043.pdf)) is a typical auxiliary data structure. The auxiliary data structure of [SQLite FTS](https://www.sqlite.org/fts3.html#data_structures) is based on cleverly encoded, prefix-compressed [B+-trees](https://en.wikipedia.org/wiki/B%2B_tree).

It's possible to run tag searches very quickly (taking a few seconds for 1 million files with thags) by running a subset query on a database with a full-text index on the tags field (space-separated string containing the tags a file has), and excluding files without tags.

Full-text index support in popular open source database systems:

* SQLite (sqlite3) has [FTS3 and FTS4](https://www.sqlite.org/fts3.html) (very similar to each other), and also [FTS5](https://www.sqlite.org/fts5.html).
* MariaDB has [FULLTEXT index](https://mariadb.com/kb/en/full-text-index-overview/) in CREATE TABLE and CREATE INDEX, with many storage engines.
* MySQL has [FULLTEXT index](https://dev.mysql.com/doc/refman/5.6/en/create-table.html) in CREATE TABLE and CREATE INDEX, with the MyISAM and InnoDB storage engines.
* PostgreSQL has the [GIN and GIST indexes](https://www.postgresql.org/docs/9.5/textsearch-tables.html) in CREATE TABLE and CREATE INDEX.

Please note that the SQL operator syntax for doing a subset query and also the syntax of the subset query itself depends on the database. Some of them is limited, for example they support *2020 AND NOT university*, but they don't support just *NOT university*. The unsupported functionality can be emulated by simplifying the subset query (i.e. making it match more), and filtering the results. In some cases it will be slow, for example to run *NOT university*, we'd ask for all files (full, sequential table scan).

As an alternative and complement to the database with a full-text index, a text file storing filename--tags pairs (i.e. export output) can be used as an index, let's call it *simple index*. To run a search on a simple index, the entire index file has to be read, parsed and matched, thus it's much slower than the full-text index. However, it doesn't have any database dependencies (which is only a small advantage, because SQLite is easy to install nowadays, and database creation is fully automatic), and its file format is simpler and long-term stable (thus it's better suited for backups), and it can also store old tags, serving as a historical archive, and it can be used to restore tags in case of loss (e.g. when an editor saves the file, losing tags). According to an early benchmark, reading and parsing a simple index containing 1 million files and doing a match on a single tag takes less than 1 minute if the search code is implemented in hand-optimized Perl. (TODO: Run some benchmarks on a fast modern CPU, compare Perl and C implementation.)

A full index rebuild does a full export (which typically involves a recursive file and directory scan), resets the index file to empty, and inserts the exported filename--tags pairs to the index. The slowest of these operations is usually the recursive file and directory scan, but population of the index can also be slow (because of the auxiliary data structures), especially if done on an HDD. To speed it up for SQLite, start from an empty in-memory database, insert all pairs, and then save the in-memory database to a temporary file (see [here](https://stackoverflow.com/q/1437327) how) without journaling, and then move the temporary file over to the previous index database file. The in-memory database may temporarily use a lot of memory (~300 MiB for 1 million files with tags), but that's small enough on desktop systems.

A partial index update only updates tags for files within a subtree, and it can be much faster than a full index rebuild, because the recursive file and directory scan is done only on the subtree. (Typical large sizes: 1 million files with tags in the index, 10 000 files in the subtree, 1 000 files with tags in the subtree, less than 1 000 index entries will be modified.) However, for the simple index, the full index file has to be read and parsed (but not written), which can be slow.

It's possible to have automatic full index updates by using a recursive filesystem watcher. See kernel module [rfsdelta](https://github.com/pts/rfsdelta) for Linux 2.6 and its userspace client [mmfs_rfsdelta_watcher.pl](https://github.com/pts/movemetafs/blob/master/mmfs_rfsdelta_watcher.pl) for an example implementation. However, this approach is fragile, because on Linux it requires a custom kernel module (which may crash the system, and it is a maintenance burden on the developer), it has occasional synchronization isses, and the user has to pay attention to start the recursive filesystem watcher program before changes are made to the filesystem. Thus this automation (and speedup) is not recommended for general use.

It's possible to speed up partial index updates by using propagating last-modification times to figure out that an entire subtree hasn't changed, thus the recursive file and directory scan is not needed for that subtree. A propagating last-modification time is a timestamp attached to each directory, which gets bumped every time anything (relevant) in that subtree changes. The bump propagates up to the top directory of the filesystem. Unfortunately most filesystems and operating systems don't support propagating last-modification times, but by writing a kernel module it's possible to change the regular last-modification time (mtime) field to a propagating one. See kernel module [rmtimeup](https://github.com/pts/ppfiletagger/tree/master/rmtimeup) and its userspace client [ppfiletagger/scan.py](https://github.com/pts/ppfiletagger/blob/master/ppfiletagger/scan.py) for an example implementation. Since it's kernel module, it is a maintenance burden on the developer. It may also affect other software which expects the last-modification time to be unchanged. It also doesn't make partial index updates instantenous, because it doesn't make fully reading the old index any faster, and it still spends a lot of time (mostly with HDDs) on non-recursively listing (and scanning) the entire contents of directories with (a few) file changes. Also the user has to load the kernel module on all systems on which they want to do tagging. Thus this speedup is not recommended for general use.

Another idea to speed up partial index updates is splitting the index file to a few (~100) smaller index files, one per large subtree. This needs some measurements, setup and regular (in-the-future) tuning done by the user. Thus this speedup is not recommended for general use.

### Working with an SQLite full-text index

The minimum supported version is SQLite 3.8.0 (released on 2013-08-26), because `notindexed=` was introduced there. Only the *sqlite3* command-line tool is needed, it will be run as a subprocess.

A full index rebuild looks like this:

```
$ rm -f index.db3.tmp
$ sqlite3 -batch -init /dev/null/missing index.db3.tmp "
PRAGMA journal_mode = off;  -- For speedup.
PRAGMA synchronous = off;  -- For speedup.
PRAGMA temp_store = memory;  -- For speedup.
PRAGMA cache_size = -16384;  -- 16 MiB. For speedup.
BEGIN EXCLUSIVE;  -- Speedup by a factor of ~3.77.
-- The final version will have case sensitive matches in tags.
-- It's not possible to enforce UNIQUE(filename) in an fts4 table,
-- but we will manually ensure that there are no duplicate filenames.
CREATE VIRTUAL TABLE assoc USING fts4(filename, notindexed=filename, tags, matchinfo=fts3);
INSERT INTO assoc (filename, tags) VALUES
('dir1/file11', 'foo bar'),
('dir1/file12', 'foo bar'),
('dir2/file21', 'foo bar'),
('dir2/file22', 'foo bar'),
('dir2/dir23/file231', 'foo bar'),
('dir2/file24', 'foo bar'),
('dir3/file31', 'foo bar'),
('dir3/file32', 'foo foobar');
COMMIT;
-- TODO: Speedup: The final version will use an in-memory database up to
--       this point, and then .clone here.
"
# TODO: Better move the journal file atomically?
$ rm -f index.db3-journal
$ mv -f index.db3.tmp index.db3
```

A partial index update of *dir2* looks like this:

```
$ sqlite3 -batch -init /dev/null/missing index.db3 "
PRAGMA synchronous = off;  -- For speedup if power outages are unexpected.
PRAGMA temp_store = memory;  -- For speedup.
PRAGMA cache_size = -16384;  -- 16 MiB. For speedup.
PRAGMA case_sensitive_like = true;
BEGIN EXCLUSIVE;  -- For speedup and synchronization.
-- Slow, sequential scan.
SELECT rowid, tags, filename FROM assoc WHERE filename LIKE 'dir2/%';
-- Result of the SELECT above:
--   3|foo bar|dir2/file21
--   4|foo bar|dir2/file22
--   5|foo bar|dir2/dir23/file231
--   6|foo bar|dir2/file24
-- dir2/file21 was removed, dir2/file24 was untagged.
DELETE FROM assoc WHERE rowid in (3, 6);
UPDATE assoc SET tags = 'bar quux' WHERE rowid = 5;
INSERT INTO assoc (filename, tags) VALUES
('dir2/file25', 'foo bar'),
('dir2/file26', 'foo bar');
-- Tags of dir2/file22 remain unchanged. In a typical index, most of
-- the tags would remain unchanged.
COMMIT;
"
```

A search with a subset query looks like this if sqlite3 was compiled with `-DSQLITE_ENABLE_FTS3_PARENTHESIS`:

```
$ sqlite3 -batch -init /dev/null/missing -separator " :: " index.db3 "SELECT tags, filename FROM assoc WHERE tags MATCH '(foo bar NOT baz) OR quux'"
foo bar|dir1/file11
foo bar|dir1/file12
foo bar|dir2/file22
bar quux|dir2/dir23/file231
foo bar|dir3/file31
foo bar|dir2/file25
foo bar|dir2/file26
```

A search with a subset query looks like this if sqlite3 was compiled without `-DSQLITE_ENABLE_FTS3_PARENTHESIS`:

```
$ sqlite3 -batch -init /dev/null/missing -separator " :: " index.db3 "SELECT tags, filename FROM assoc WHERE tags MATCH 'foo bar -baz'"
foo bar :: dir1/file11
foo bar :: dir1/file12
foo bar :: dir2/file22
foo bar :: dir3/file31
foo bar :: dir2/file25
foo bar :: dir2/file26
```

Please note that `-DSQLITE_ENABLE_FTS3_PARENTHESIS` can be detected detecting an error:

```
$ sqlite3 -batch -init /dev/null index.db3 "SELECT 1 FROM assoc WHERE tags MATCH 'NOT' AND rowid=0 AND rowid<rowid"
Error: malformed MATCH expression: [NOT]
```

A search with a subset query with a subtree restriction (only within *dir2*) looks like this:

```
$ sqlite3 -batch -init /dev/null/missing -separator " :: " index.db3 "PRAGMA case_sensitive_like = true; SELECT tags, filename FROM assoc WHERE tags MATCH 'foo bar' AND filename LIKE 'dir2/%'"
foo bar :: dir2/file22
foo bar :: dir2/file25
foo bar :: dir2/file26
```

### Simple index file format

The file format of the *simple index* is line-oriented and mostly append-only. Each line (except for some marker lines) contains information about a single file, including filename (pathname), comma-delimited list of tags and some other option fields ignored at search time. A typical index file looks like this:

```
this=simple-index-v1 at=1600000000
ct=,foo,bar, f=dir1/file11
ct=,foo,bar, this middle part is ignored f=dir1/file12
ct=,foo,bar, f=dir2/file21
ct=,foo,bar, f=dir2/file22
ct=,foo,bar, f=dir2/dir23/file231
ct=,foo,bar, f=dir2/file24
ct=,foo,bar, f=dir1/file31
ct=,foo,foobar, f=dir1/file32
p=done at=1600001000 fat=1600001001
```

The `ct=,...,` value contains the comma-separated list of *current tags* (in arbitrary order), including a comma at both sides. The list of tags is not empty, files without tags are not mentioned.

There must be at most one line for each filename. If there are more, only one of those lines may start with `ct=`.

How to do a partial index update:

1. Read the index file from the beginning until a line starting with `p=done`, `p=redo` or `p=half` (plus a space each) or EOF is found.
1. If `p=redo` or `p=half` or EOF is found, then either fail with the error *another index update pending or failed* or do a repair (see below). After a successful repair, there is a `p=done` at the end, continue from there.
1. A line starting with `p=done` (plus a space) has been encountered. If it is not followed by EOF, fail with the error *EOF exected after p=done line*.
1. Replace the beginning of the encountered trailing `p=done` line with `p=redo`.
1. In arbitrary order:
   * For each new or with-tag-changes file, append a line of the form `ct=,TAGS, ...f=FILENAME`.
   * For each deleted file, replace the beginning of the `ct=` line with `Dt=` (*deleted tag*).
   * For each all-tags-removed files, replace the beginning of the `ct=` line with `Ft=` (*former tag*).
   * For each with-tag-changes file, replace the beginning of the old `ct=` line with `Mt=` (*modified tag*).
1. Append a `p=done at=TIMESTAMP fat=??????????` line (with question marks), with `TIMESTAMP` being the [Unix timestamp](https://en.wikipedia.org/wiki/Unix_time) at the time the partial index update has started (*start timestamp*).
1. Replace the beginning of the `p=redo` line with `p=half`.
1. Replace the beginning of all `Dt=` lines with `dt=', `Ft=` lines with `ft=`, `Mt=` lines with `mt=` in the file.
1. Update the `fat=...` (*finish timestamp*) value in appended `p=done` line to the current Unix timestamp.
1. Replace the beginning of the `p=half` line with `p=done`.

An example index file after a partial index update of *dir2* (in which dir2/file21 has been removed, dir2/file24 has been untagged, tags of dir2/dir23/file231 have been changed, dir2/file25 and dir2/file26 have been added):

```
this=simple-index-v1 at=1600000000
ct=,foo,bar, f=dir1/file11
ct=,foo,bar, this middle part is ignored f=dir1/file12
lt=,foo,bar, f=dir2/file21
ct=,foo,bar, f=dir2/file22
lt=,foo,bar, f=dir2/dir23/file231
lt=,foo,bar, f=dir2/file24
ct=,foo,bar, f=dir1/file31
ct=,foo,foobar, f=dir1/file32
p=cont at=1600001000 fat=1600001001
ct=,bar,quux, f=dir2/dir23/file231
ct=,foo,bar, f=dir2/file25
ct=,foo,bar, f=dir2/file25
p=cont at=1600002000 fat=1600002001
```

Run a search like this:

1. For each line from the beginning in the index file:
   * If the line starts with `at=,`, do the tag match, and print the filename on a match. (Print and forget immediately, don't keep matching files in memory.)
   * Otherwise, if the line starts with `p=done`, stop completely.
   * Otherwise, if the line starts with `p=redo`, stop processing the index file, and continue below.
   * Otherwise, ignore the line.
1. Seek back to the beginning of the index file, and for each line:
   * If the line starts with `at=,`, `Ct=,`, `Dt=,` or `Mt=,`, do the tag match, and print the filename on a match. (Print and forget immediately, don't keep matching files in memory.)
   * Otherwise, if the line starts with `p=done` or `p=redo`, stop completely.
   * Otherwise, ignore the line.

The second scan after `p=redo` makes the search see and consider previous, to-be obsoleted tags strings when a partial index update is running (slowly) in the `p=redo` phase in another process. Without the second scan, some filename--tags pairs would be ignored.

Mandatory locking on the index file should be used to wrap around partial index updates. Without locking, the index file can be corrupted (e.g. more than one `p=done` line) if there are more than one partial index updates running. Some network filesystems don't respect mandary locking.

A partial index update may abort unexpectedly at any point, never completing this work. Before a new partial index update can be started, the index file has to be repaired. Repair it like this:

1. Check the last-modification time of the index file. If the absolute difference from the current timestamp is less than 2 hours:
   1. Check the last-modification time of the index file repeatedly: every 0.2 second for 10 seconds. Stop if it has changed.
   1. If the last-modification time of the index file has changed in the last 10 seconds, restart from the beginning of the instructions.
   1. (Now it's very likely that other updates on the same index files have already finished.)
1. Read the index file from the beginning until a full line starting with `p=done`, `p=redo`, `p=half`, an incomplete line or EOF is found.
1. If an incomplete line was found, then remove it by truncating the file, and assume that EOF was found.
1. If EOF was found, add `p=done at=... fat=???`, setting `at=` to the Unix timestamp at the time the repair started, and `fat=` to the current Unix timestamp. Stop with success.
1. If `p=done` was found:
   1. If `p=done` isn't immediately followed by EOF, fail with *EOF expected after p=done line*.
   1. If the `p=done` line has a `fat=???...` attribute (with question marks), than set to the current Unix timestamp.
   1. Stop with success.
1. If `p=half` was found:
   1. Continue reading lines until a full line starting with `p=done`, `p=redo`, `p=half`, an incomplete line or EOF is found.
   1. Unless `p=done` was found immediately followed by EOF, fail with *p=done expected after p=half*.
   1. Replace the beginning of all `Dt=` lines with `dt=', `Ft=` lines with `ft=`, `Mt=` lines with `mt=` in the file until the first `p=half` (already found).
   1. Replace the beginning of the `p=half` line with `p=done`, update the `fat=...` (*finish timestamp*) value to the current Unix timestamp, and rename it to `rat=...` (*repair timestamp*).
   1. Stop.
1. If `p=redo` was found:
   1. Replace the beginning of all `Dt=`, `Ft=` and `Mt=` lines with `ct=` in the file until the first `p=redo` (already found).
   1. Truncate the file after the `p=redo` line.
   1. Replace the beginning of the `p=redo` line with `p=done`.
