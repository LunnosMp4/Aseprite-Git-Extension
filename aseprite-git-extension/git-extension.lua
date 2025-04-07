local selectedGitFolder = nil

local function getUserHome()
  return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

local gitFolderCacheFile = getUserHome() .. "/.aseprite_git_folder"

local function extractFolder(path)
  path = path:gsub("\\", "/")
  return path:match("^(.*)/[^/]+$")
end

local function folderIsValidGitRepo(path)
  local command
  if package.config:sub(1,1) == "\\" then
    -- Windows
    command = string.format('if exist "%s\\.git\\" (exit 0) else (exit 1)', path)
  else
    -- macOS/Linux
    command = string.format('[ -d "%s/.git" ]', path)
  end

  local result = os.execute(command)
  return result == true or result == 0
end


local function saveGitFolderPath(path)
  local f = io.open(gitFolderCacheFile, "w")
  if f then
    f:write(path)
    f:close()
  end
end

local function loadGitFolderPath()
  local f = io.open(gitFolderCacheFile, "r")
  if f then
    local path = f:read("*all")
    f:close()
    if path ~= "" and folderIsValidGitRepo(path) then
      selectedGitFolder = path
    end
  end
end

-- Dialog to pick folder (via file then trimming)
local function pickGitFolder()
  local dlg = Dialog("Select Git Folder (via file)")
  dlg:file{
    id = "path",
    label = "Pick a file inside your Git folder",
    open = true,
    filetypes = { "aseprite", "png", "jpg", "gif", "*" },
    filename = ""
  }
  dlg:button{ id = "ok", text = "Set Folder" }
  dlg:button{ id = "cancel", text = "Cancel" }
  dlg:show()

  local data = dlg.data
  if data.ok and data.path and data.path ~= "" then
    local folder = extractFolder(data.path)
    if folderIsValidGitRepo(folder) then
      selectedGitFolder = folder
      saveGitFolderPath(folder)
      app.alert("Success: Git folder set to: " .. selectedGitFolder)
    else
      app.alert("Error: This folder does not contain a .git repository.")
      selectedGitFolder = nil
    end
  else
    app.alert("No valid file selected.")
  end
end

-- Function to get the output of a command
local function getCommandOutput(command)
  local fullCommand = string.format('cd "%s" && %s', selectedGitFolder, command)
  local handle = io.popen(fullCommand)
  if handle then
    local output = handle:read("*all")
    handle:close()
    return output
  end
  return nil
end


-- Show Git status dialog
local function showGitStatusDialog(title, command)
  if not selectedGitFolder or not folderIsValidGitRepo(selectedGitFolder) then
    app.alert("Please set a valid Git folder first.")
    return
  end

  local fullCommand = string.format('cd "%s" && %s', selectedGitFolder, command)
  local handle = io.popen(fullCommand)
  if not handle then
    app.alert("Failed to run: " .. command)
    return
  end

  local output = handle:read("*all")
  handle:close()

  if not output or output == "" then
    output = "(no output)"
  end

  local dlg = Dialog(title)
  dlg:label{ label = "Changes:" }
  dlg:separator()
  dlg:label{ id="output", text=output }
  dlg:button{ text="OK" }
  dlg:show()
end

-- Run a Git command from the selected folder
local function runGitCommand(command, actionName)
  if not selectedGitFolder then
    app.alert("Please set a Git folder first.")
    return 84
  end

  local fullCommand = string.format('cd "%s" && %s', selectedGitFolder, command)
  local result = os.execute(fullCommand)

  if result then
    app.alert(actionName .. " succeeded!")
  else
    app.alert(actionName .. " failed. Check the console.")
  end
end

-- Git Commit Dialog
local function git_commit()
  local status = getCommandOutput("git status --porcelain")

  if not status or status == "" then
    app.alert("Nothing to commit. Working directory is clean.")
    return
  end

  showGitStatusDialog("Git Status", "git status --short")

  local dlg = Dialog("Git Commit")
  dlg:entry{ id="message", label="Commit Message", text="Update art" }
  dlg:button{ id="ok", text="Commit" }
  dlg:button{ id="cancel", text="Cancel" }
  dlg:show()

  local data = dlg.data
  if data.ok and data.message and data.message ~= "" then
    local message = data.message
    runGitCommand('git add . && git commit -m "' .. message .. '"', "Git Commit")
  end
end

local function git_pull()
  -- fetch first so we can diff
  if runGitCommand("git fetch", "Fetch") == 84 then
    return
  end

  local diff = getCommandOutput("git diff HEAD..origin/HEAD")
  if not diff or diff == "" then
    app.alert("Already up to date. No changes to pull.")
    return
  end

  -- Show preview of incoming changes
  showGitStatusDialog("Incoming Changes (diff)", "git diff HEAD..origin/HEAD")

  -- Then ask user to confirm
  local result = app.alert{
    title = "Confirm Pull",
    text = "Do you want to pull these changes?",
    buttons = { "Yes", "Cancel" }
  }

  if result == 1 then
    runGitCommand("git pull", "Git Pull")
  end
end

local function git_push()
  runGitCommand("git push", "Git Push")
end

local function git_set_folder()
  pickGitFolder()
end

-- Register commands
function init(plugin)
  -- Load the saved Git folder path
  loadGitFolderPath()
  
  plugin:newCommand{
    id = "GitSetFolder",
    title = "Git: Set Folder",
    group = "file_scripts",
    onclick = git_set_folder
  }

  plugin:newCommand{
    id = "GitCommit",
    title = "Git: Commit",
    group = "file_scripts",
    onclick = git_commit
  }

  plugin:newCommand{
    id = "GitPull",
    title = "Git: Pull",
    group = "file_scripts",
    onclick = git_pull
  }

  plugin:newCommand{
    id = "GitPush",
    title = "Git: Push",
    group = "file_scripts",
    onclick = git_push
  }
end
