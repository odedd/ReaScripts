-- @noindex
TEXTS = {}

TEXTS.CAUTION_MINIMIZE =
[[Since you have selected not to backup to a new folder, all* audio 
source files will be DELETED and replaced by new "minimized"
versions.

This will make any other RPP that uses the original files UNUSABLE!
The only project that will work with those new files is this one.

This cannot be undone!

*Audio files outside of this project's folder will not be deleted.]]

TEXTS.CAUTION_COLLECT_MOVE =
[[The files will no longer exist in their original location, which will
make them unusable for any other project or application that needs them]]

TEXTS.CAUTION_DELETE =
[[These files will be deleted forever. This cannot be undone!]]

TEXTS.CAUTION_CLEAN_MEDIA_FOLDER =
[[This will make any other RPP that uses files in the media folder UNUSABLE!
The only project that will work with those new files is this one.

This is especially risky if your media folder is your project's root folder,
as this will delete any media file which exists in this folder, which may be
renders etc.]]

TEXTS.ERROR_KEEP_IN_FOLDER = 'A deletion method must be selected if "Clean Media Folder" is checked'
TEXTS.ERROR_NO_BACKUP_DESTINATION = 'Must select backup destination folder'
TEXTS.ERROR_BACKUP_DESTINATION_MISSING = 'Backup destination folder does not exist'
TEXTS.ERROR_BACKUP_DESTINATION_MUST_BE_EMPTY = 'Backup destination folder must be empty'
TEXTS.ERROR_NOTHING_TO_DO =
[[            ¯\_('')_/¯
    
      Nothing for me to do.

Please give me at least one task.
]]

TEXTS.ERROR_SUBPROJECTS_UNSPPORTED =
([[Subprojects not (yet?) supported.

If you wish to archive this project
please first render the subprojects
by gluing them, and then run
%s again.]]):format(Scr.name)

TEXTS.ERROR_NETWORKED_FILES_TRASH_UNSPPORTED =
[[Networked files were found.

Moving networkd files to the
trash is not supported.

Please select deleting files
or consider backing up instead
of minimizing.]]

TEXTS.WARNINGS_EXIST =
[[There are several warnings (those yellow icons with the !s).
You can hover over them to see each one.

Do you accept the risks?]]

TEXTS.BETA_WARNING =
[[This script is not even at version 1.0!
Are you crazy?!

While I'm pretty damn sure everything works
you should still probably make sure to have
a backup of this project and all of its
media files, until you're certain that
this script did its job correctly.

I'm not taking responsibility in case
anything goes wrong.

Which reminds me - please let me know at the
Reaper forums if anything does go wrong so
I can fix it.



But everything wil probably be ok :)

]]