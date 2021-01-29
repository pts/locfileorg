# Search

A search operation takes a search query string (see below), and a top-level directory (folder), and returns a list of files matching the query.

## Search query

* To search for files having all of the desired tags, specify the tags separated by spaces. For example, `sweet sour` matches all the files which have both tags `sweet` and `sour`. Thus it matches `sweet sour soup`, but it doesn't match `sweet soup`.

* To search for files having any of the desired tags (i.e. alternates), specify the tags separated by pipes (`|`). For example, `sweet | salty` matches all files which have either tag `sweet` or `salty` or both. Spaces around `|` are optional, so `sweet|salty` works equivalenty.

* You can combine all-tags and any-tags reqirement. For example, `sweet sour | salty` matches a file iff it has both tags `sweet` and `sour`, and/or it has the tag `salty`. Thus it matches `salty yellow` and `sweet sour salty yellow`, but won't match `sweet yellow`. (We say that space has higher precedence than `|`.)

* It's not possible to specify have any-tags in the middle. For example, `(starter | soup) main (dessert | cheese)` causes an error (because parentheses are not allowed). If you want a tagged meal containing a `starter` or a `soup`, and also conaining a `main`, and also containing a `dessert` or a `cheese`, then specify it expanded like this: `starter main dessert | starter main cheese | soup main dessert | soup main cheese`. Another example: `(salty soup) | (sweet cake)` causes an error, specify it without parentheses to make it work.

* Tag matches are case sensitive by default. Some search engines support case insensitive searches, but you have to enable that at search time, and usually also at index building time.

* To search for files without a desired tag, specify `-` in front of the tag. For example, `sweet sour -salty -bitter` matches all files which have both tags `sweet` and `sour`, but not any of the tags `salty` or `bitter`.

* To search for files having any tag, specify `*`. For example, `-foo * | bar` matches a file if either it has no tag `foo`, but it has any (other) tag, or it has the tag `bar`.

* To search for files without any tag, specify `-*`. For example `-* | foo bar` matches a file if either it has no tags at all, or it has both tags `foo` and `bar` (and possibly others). Please note that some search engines don't store files files without tags in their index, and they report an error if the query contains `-*` or if it doesn't contain a positive tag match.

* To search for files which have at least one tag other than the specified tags, specify `*-` in front of those tags. For example, `*-sweet *-sour` matches `bitter` and `bitter sweet`, but it doesn't match `sweet` or `sweet sour`.

* You can search for tags starting with `v:` as usual, for example `v:foo -v:bar` matches files which have tag `v:foo`, but not `v:bar`.

* A tag is a word containing one or more of these characters: ASCII letters (*A* to *Z* and *a* to *z*, without accents or diacritics), ASCII digits (*0* to *9*), ASCII underscore (`_`) and all non-ASCII Unicode characters (code point 128 and above, including letters with accents and diacritics). In addition to these characters, a tag can have the `v:` prefix.

* Additionally, you can specify some special terms:

  * `:any` matches any file. For example, `foo :any bar` is equivalent to `foo bar`, and `:any` is eqivalent to `* | -*`.

  * `:tag` and `:tagged` are equivalent to `*`: they match files having any tag.

  * `:none` and `-:tag` are equivalent to `-*`: they match files without a tag.

  * `ext:...` matches a file with the specified extensions separated by slashes. For example, `ext:doc/docx/odt` matches any file whose name ends with `.doc`, `.docx` or `.odt`, and `-ext:doc/docx/odt` matches the opposite. Filename match is case insensitive in ASCII, i.e. it treats uppercase ASCII letters (*A* to *Z*, without accents or diacritics) equivalent to lowercase.

* You an also match by file type:

  * `:vid`, `:video`, `:film` and `:movie` match video files. (Their negative, e.g. `-:vid`, matches non-video files.)

  * `:pic`, `:picture`, `:img`, `:image` match image files. (Their negative, e.g. `-:vid`, matches non-video files.)

  * `:aud`, `:audio`, `:snd`, `:sound` match audio files. (Their negative, e.g. `-:aud`, matches non-audio files.)

  * Most search engines implement type detection by comparing the filename extension to a short, hardcoded list (e.g. it detects `*.jpeg` file is an `:image`).

## Search engines

* *tagfind*

  * It is the search engine used by the *find* and *grep* commands in [locfileorg](https://github.com/pts/locfileorg) and [ppfiletagger](https://github.com/pts/ppfiletagger). It works by doing a recursive file and directory scan, or by reading a file containing filename--tags pairs.

  * It follows symlinks to directories and files. Soon it will be changed to follow symlinks to files, but not to directories.

  * It can return files which don't have any tags.

  * It doesn't support file type detection, it reports an error for the file type special terms (e.g. `:video`). Soon it will get support, using filename extension.

  * It doesn't support `ext:...`, and it reports an error if the query contains it.

* *tagquery*

  * It is the search engine used by the *query* command (currently unimplemented) in [locfileorg](https://github.com/pts/locfileorg). It works by consulting an index file containing filename--tags pairs in a fast-to-search format. If the index is an [SQLite FTS4](https://www.sqlite.org/fts3.html) full-text index, then the search is very fast (because only the relevant, tiny fraction of the index file is consulted). If the index is a simple index, then the entire file is read sequentially; the parsing is CPU-optimized, and is still much faster than a recursive file and directory scan.

  * It follows symlinks to files, but not to directories.

  * It reports an error if the query is explicitly asking for or can match files which don't have any tags.

  * It supports file type detection, by comparing the filename extension to a short, hardcoded list (e.g. it detects `*.jpeg` file is an `:image`), but it's slow.

  * It supports `ext:...`, but it's slow.

* *rmtimequery*

  * It is a search engine used by the *rmtimequery* tool and [ppfiletagger](https://github.com/pts/ppfiletagger). It works by consulting an index file containing filename--tags pairs, of the [SQLite FTS4](https://www.sqlite.org/fts3.html) full-text index format, and filtering the results in Python code. It's quite fast, but not as fast as *tagquery*, because it also populates some helper tables, and runs a join of 2 tables at query time.

  * It follows symlinks to files, but not to directories.

  * It reports an error if the query is explicitly asking for or can match files which don't have any tags.

  * It supports file type detection, by comparing the filename extension to a short, hardcoded list (e.g. it detects `*.jpeg` file is an `:image`), but it's slow.

  * It supports `ext:...`, but it's slow.
