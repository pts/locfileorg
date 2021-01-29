# Tagging

## Introduction

* Each file has a set of tags (empty by default). Tagging is adding or removing tags to one or more files. You specify the list of filenames and the tag modifications to apply (as a single string called `<tagspec>`).

* Tags are invented by you (the user), there are no predefined tags. Some recommendations for photo galleries: Add tags indicating ...

  * when the photo was taken (e.g. `2021`)
  * what kind of people are visible on the photo (e.g. `family`, `friends`, `kids`)
  * which specific people are present (e.g. `uncle_Sam`)
  * the scenery (e.g. `indoors`, `urban`, `nature`, `beach`, `underwater`)
  * the occasion (e.g. `birthday`, `contest`)
  * the actions depicted (e.g. `cooking`, `singing`)

* An advice: Don't be obsessed by adding all imaginable tags to each file (that would be too slow, you never finish), but add a few tags in the beginning, which you are likely to search in the future. You can always add more tags later.

* How to do simple modifications:

  * To add a few tags (`<tag>` or `v:<tag>`), specify them in the `<tagspec>`, separated by whitespace. For example, `foo v:Bar` adds `foo` and `v:Bar`.

  * To remove a few tags (`<tag> or `v:<tag>`), specify them starting with `-` in the `<tagspec>`. For example, `foo -v:Bar v:food -baz` adds `foo` and `v:food`, and it removes `v:Bar` and `baz`.

  * To remove all tags, specify `.` or `-*` as the `<tagspec>`.

  * To overwrite all tags (i.e. ignoring any tags the file already has), start the `<tagspec>` with `.` or `-*`, and then specify the tags (`<tag> or `v:<tag>`) separated by whitespace.

* Most tag modifications (including all the simple ones above) require that the specified `<tag>`s are whitelisted in a configuration file. This is to prevent typos and synonyms in added tags.

* Tags are case sensitive.

* As a beginner, don't worry about tags starting with `v:`; simply don't add those to any files.

## More details

* The characters allowed in a `<tag>` are limited. A <tag> is a nonempty single word. Valid characters are ASCII lowercase letters (*a* .. *z*), ASCII uppercase letters (*A* .. *Z*), ASCII underscore (*\_*), and non-ASCII Unicode characters (*U+0080* ..  *U+1FFFFF*) encoded as UTF-8.

* Thus the following bytes are allowed in a `<tag>` (specified as a regexp character class): `[\x00-\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x7F\xC0\xC1\xF5-\xFF]`.

* Thus the following bytes are disallowed in a `<tag>`: `[\x30-\x39\x41-\x5A\x5F\x61-\x7A\x80-\xBF\xC2-\xF4]`. In addition to that, an empty `<tag>` and one which contains invalid UTF-8 are invalid.

* Each whitelisted `<tag>` has a corresponding `v:<tag>`, which can be added independently to files. `v:` is an abbreviation for vetted, and a file with `v:<tag>` added means that a human has explicitly considered (vetted) whether `<tag>` should be added to this file, and added it acordingly. Thus:

  * If neither `<tag>` or `v:<tag>` is added, then we don't have information whether the tag is relevant for that file.

  * If `<tag>` is added, but `v:<tag>` isn't, then we have a weak positive indication that the tag is relevant for that file. The tag may have been added by an automated process (e.g. all image files in a folder tagged as `family`, without actually looking at them to find exceptions).

  * If both `<tag>` or `v:<tag>` are added, then that's a strong positive indication that the tag is relevant for a file, because a human has looked at the individual file, and has made the decision.

  * If `<tag>` is not added, but `v:<tag>` is, then that's a strong positive indication that the tag is irrelevant for a file, because a human has looked at the individual file, and has made the decision.

* A `<tagspec>` (specification of tag modifications) is a list of items separated by whitespace or comma. The first item (optional) indicates the tagging mode, and subsequent items indicate which tags to add and/or remove. The order of these subsequent items doesn't matter, and duplicates are ignored.

* Tagging modes:

  * change mode (`++`, default): The specified tags will be added (starting with or without `+`) or removed (starting with `-`), other tags are unchanged.
  * overwrite mode (`.` or `-*`): All tags the file already has will be removed, and then the specified tags will be added.
  * merge mode (`+`): The specified tags will be added or removed according to the merge item rules below. This is useful for merging the tags on two copies of the same file, which were tagged independently. Details:
    * Let's suppose that two files have been tagged independently, and now you discover that they are the same, and thus they need to same tags.
    * You can use merge mode to get a merged union of tags: apply `+ <tags-of-file-A>` to file B, and/or (equivalently) `+ <tags-of-file-B>` to file A. (`v:<tag>` tags are also included here.)
    * Sometimes it's necessary to remove tags from the union while merging: remove each `<tag>` if any the input file has `v:<tag>`, but not `<tag>`. For example, when merging 3 files with tags `foo bar`, `foo v:foo baz`, `bar v:baz`, the union is `foo v:foo bar baz v:baz`, but `baz` will be removed, because `bar v:baz` contains `v:baz` without `baz`. So the result of the merge is `foo v:foo bar v:baz`.
    * To merge more than two files, modify the first file with tags from each other file in merge mode, and then modify each other file with tags from the first file in merge mode.
    * Tagging software may have a convenience feature to merge file tags using the union + removal logic above, and then you don't have to understand the details of merge mode.

* Items in change mode:

  * `<tag>`, `v:<tag>`, `+<tag>`, `+v:<tag>`: Add the specified tag to the file. `<tag>` must be on the whitelist. If tha same tag is also specified with `---`, then it will be removed instead.
  * `-<tag>`, `-v:<tag>`: Remove the specified tag from the file. `<tag>` must be on the whitelist. It's an error (sign conflict) to add and remove the same tag (except if the removal is done with `---` instead below).
  * `---<tag>`, `---v:<tag>`: Forcibly remove the specified tag from the file. `<tag>` may be missing from the whitelist. If the same tag is to be added and removed with `---`, then it will be removed.

* Items in overwrite mode:

  * `<tag>`, `v:<tag>`, `+<tag>`, `+v:<tag>`: Add the specified tag to the file. `<tag>` must be on the whitelist.
  * `-<tag>`, `-v:<tag>`: It's an error to use these items in overwrite mode.
  * `---<tag>`, `---v:<tag>`: Forcibly prevent the specified tag from being added to the file. `<tag>` may be missing from the whitelist. If the same tag is to be added and removed with `---`, then it won't be added.

* Items in merge mode (merge item rules):

  * `<tag>`, `+<tag>`: `<tag>` must be on the whitelist. If `---<tag>` is also specified, ignore it. Otherwise, if `-<tag>` is also specified, report an error (sign conflict). Otherwise, if `v:<tag>` is also specified, and the file has `v:<tag>`, but no `<tag>`, report an error (tag merge conflict). Otherwise, if `v:<tag>` is not specified, and the file has `v:<tag>`, ignore it. Otherwise, add `<tag>` to the file.
  * `v:<tag>`, `+v:<tag>`: `<tag>` must be on the whitelist. If `---v:<tag>` is also specified, ignore it. Otherwise, if `-v:<tag>` is also specified, report an error (sign conflict).  Otherwise, if none of `<tag>`, `-<tag>` or `---<tag>` is specified, and the file has both `<tag>` and `v:<tag>`, report an error (tag merge conflict). Otherwise, if `<tag>` is specified, and the file has `v:<tag>`, but no `<tag>`, report an error (tag merge conflict). Otherwise, if `<tag>` is not specified, and the file doesn't have `v:<tag>`, remove `<tag>`, and add `v:<tag>`.  Otherwise, add `v:<tag>` to the file.
  * `-<tag>`: `<tag>` must be on the whitelist. If `---<tag>` is also specified, ignore it. Otherwise, if `<tag>` is also specified, report an error (sign conflict). Otherwise, if `v:<tag>` is not specified, and the file has `v:<tag>`, ignore it. Otherwise, remove `<tag>` from the file.
  * `-v:<tag>`: `<tag>` must be on the whitelist. If `---v:<tag>` is also specified, ignore it. Otherwise, if `v:<tag>` is also specified, report an error (sign conflict). Otherwise, remove `v:<tag>` from the file.
  * `---<tag>`: If `v:<tag>` is not specified, and the file has `v:<tag>`, ignore it. Otherwise, remove `<tag>` from the file.
  * `---v:<tag>`: Remove `v:<tag>` from the file.
