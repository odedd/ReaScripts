-- @noindex
T = {}

T.CAUTION_MINIMIZE =
[[Since you have selected not to backup to a new folder, all* audio
source files will be DELETED and replaced by new "minimized"
versions.

This will make any other RPP that uses the original files UNUSABLE!
The only project that will work with those new files is this one.

This cannot be undone!

*Audio files outside of this project's folder will not be deleted.]]

T.CAUTION_COLLECT_MOVE =
[[The files will no longer exist in their original location, which will
make them unusable for any other project or application that needs them.]]

T.CAUTION_DELETE =
[[These files will be deleted forever. This cannot be undone!]]

T.CAUTION_FREEZE_REMOVE =
[[Frozen source files will be removed. Frozen tracks will become
unfrozen, making their audio permanent, and you will not be able
to revert back to their unfrozen form.]]

T.CAUTION_CLEAN_MEDIA_FOLDER =
[[This will make any other RPP that uses files in the media folder UNUSABLE!
The only project that will work with those new files is this one.

This is especially risky if your media folder is your project's root folder,
as this will delete any media file which exists in this folder, which may be
renders etc.]]

T.ERROR_KEEP_IN_FOLDER = 'A deletion method must be selected if "Clean Media Folder" is checked'
T.ERROR_NO_BACKUP_DESTINATION = 'Must select backup destination folder'
T.ERROR_BACKUP_DESTINATION_MISSING = 'Backup destination folder does not exist'
T.ERROR_BACKUP_DESTINATION_MUST_BE_EMPTY = 'Backup destination folder must be empty'
T.ERROR_NOTHING_TO_DO =
[[            ¯\_('')_/¯

      Nothing for me to do.

Please give me at least one task.
]]

T.ERROR_SUBPROJECTS_UNSPPORTED =
    ([[Subprojects not (yet?) supported.

If you wish to archive this project
please first render the subprojects
by gluing them, and then run
%s again.]]):format(Scr.name)

T.ERROR_NETWORKED_FILES_TRASH_UNSPPORTED =
[[Networked files were found.

Moving networkd files to the
trash is not supported.

Please select deleting files
or consider backing up instead
of minimizing.]]

T.WARNINGS_EXIST =
[[There are several warnings (those yellow icons with the !s).
You can hover over them to see each one.

Do you accept the risks?]]

T.BETA_WARNING =
[[This script is not even at version 1.0!
Are you sure about that?!

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

T.CANCELLED = 'Cancelled.'
T.CANCEL_RELOAD = [[


Reloading original project and deleting temporary files.
]]

T.SETTINGS = {}
T.SETTINGS.BACKUP = {
      LABEL = 'Backup project to a new folder',
      HINT = 'Copy project to a new directory, along with used media only'
}
T.SETTINGS.BACKUP_DESTINATION = {
      LABEL = 'Destination',
      HINT = 'Select an empty folder'
}
T.SETTINGS.KEEP_ACTIVE_TAKES_ONLY = {
      LABEL = 'Remove unused takes',
      HINT = 'Keep only selected takes'
}
T.SETTINGS.MINIMIZE = {
      LABEL = 'Minimize audio files',
      HINT = 'Keep only the parts of the audio that are being used in the project'
}
T.SETTINGS.PADDING = {
      LABEL = 'padding (s)',
      HINT = 'How much unused audio, in seconds, to leave before and after items start and end positions'
}
T.SETTINGS.MINIMIZE_SOURCE_TYPES = {
      LABEL = 'Only minimize those file types',
      HINT =
      'Minimizing compressed files, such as MP3s, may result in larger (!) \"minimized\" files, since those will be lossless files'
}
T.SETTINGS.GLUE_FORMAT = {
      LABEL = 'Minimized files format',
      HINT =
      'Lossless compression (FLAC and WAVPACK) will result in the smallest size without losing quality, but takes longer to create.'
}
T.SETTINGS.COLLECT_OPERATION = {
      LABEL = 'Collect external files',
      HINT = 'Copy or move external files into the project folder'
}
T.SETTINGS.COLLECT = {
      [COLLECT.EXTERNAL] = {
            order = 0,
            LABEL = "Unminimized audio files",
            HINT =
            'Copy all external audio files which were have not been minimized to a subfolder within the project\'s main folder',
            TEXT_HINT = 'Project media folder',
            TEXT_HELP = 'Folder to collect files into (eg. Audio Files). Leave empty for the project\'s media folder.',
            targetPath = FILE_TYPES.AUDIO,
            mustCollectHint = 'Must collect when backing up'
      },
      [COLLECT.VIDEO] = {
            order = 1,
            LABEL = "Video files",
            HINT = 'Copy all video files to a subfolder within the project\'s main folder',
            TEXT_HINT = 'Project media folder',
            TEXT_HELP = 'Folder to collect files into (eg. Video Files). Leave empty for the project\'s media folder.',
            targetPath = FILE_TYPES.VIDEO
      },
      [COLLECT.RS5K] = {
            order = 2,
            LABEL = "RS5K samples",
            HINT = 'Copy all used ReaSamplOmatic5000 samples to a subfolder within the project\'s main folder',
            TEXT_HINT = 'Project media folder',
            TEXT_HELP = 'Folder to collect files into (eg. RS5K Samples). Leave empty for the project\'s media folder.',
            targetPath = FILE_TYPES.RS5K
      }
}
T.SETTINGS.FREEZE_HANDLING = {
      LABEL = 'Frozen track handling',
      HINT = 'Should frozen tracks be kept frozen, keeping their source media or become unfrozen, making their changes permanent and removing the source media'
}
T.SETTINGS.CLEAN_MEDIA_FOLDER = {
      LABEL = 'Clean media folder',
      HINT = 'Keep only the files that are being used in the project in the media folder'
}
T.SETTINGS.DELETE_METHODS = {
      LABEL = 'Deletion Method',
      HINT = 'When deleting files, which method should be used?'
}
