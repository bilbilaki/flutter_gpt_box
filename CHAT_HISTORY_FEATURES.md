# Chat History Features Implementation

## Overview
This document describes the new features added to the chat history management system.

## Features Implemented

### 1. Clone Chat History
- **Functionality**: Duplicate an entire chat history with all messages
- **Location**: Available in the chat item's context menu (three dots)
- **Implementation**: `_onCloneChat()` in `lib/view/page/home/ctrl.dart`
- **Usage**: Click the three dots on any chat → Select "Clone"
- The cloned chat will have " (Copy)" appended to its name

### 2. Pin Chat History
- **Functionality**: Pin important chats to keep them at the top of the list
- **Location**: Available in the chat item's context menu
- **Implementation**: `_onTogglePinChat()` in `lib/view/page/home/ctrl.dart`
- **Visual Indicator**: Pinned chats show a pin icon on the left side
- **Sorting**: Pinned chats automatically appear at the top of their section

### 3. Color Indicators
- **Functionality**: Assign colors to chats for visual organization
- **Available Colors**:
  - 🔴 Red
  - 🟠 Orange
  - 🟡 Yellow
  - 🟢 Green
  - 🔵 Blue
  - 🟣 Purple
  - 🩷 Pink
- **Location**: Available in the chat item's context menu → "Set Color"
- **Implementation**: `_onSetColorIndicator()` in `lib/view/page/home/ctrl.dart`
- **Visual Indicator**: Shows as a colored vertical line on the left edge of the chat item

### 4. Folder Organization
- **Functionality**: Create folders to group related chats
- **Features**:
  - **Create Folder**: Click "New Folder" button at the top of the history list
  - **Move to Folder**: Use the chat context menu → "Move to Folder"
  - **Rename Folder**: Click the folder's three dots menu → "Rename"
  - **Duplicate Folder**: Click the folder's three dots menu → "Duplicate"
  - **Delete Folder**: Click the folder's three dots menu → "Delete"
    - When deleting a folder, all chats inside move to "Uncategorized"
  - **Expand/Collapse**: Click on the folder header or the expand/collapse icon
- **Implementation**: Multiple functions in `lib/view/page/home/ctrl.dart`
- **Visual Organization**: 
  - Folders appear at the top with their chat count
  - Each folder can be expanded or collapsed
  - Uncategorized chats appear in a separate section

## Technical Details

### New Data Models

#### ChatHistory Extensions
Added three new optional fields to `ChatHistory`:
- `isPinned`: Boolean - whether the chat is pinned
- `colorIndicator`: String - color identifier (red, orange, yellow, etc.)
- `folderId`: String - ID of the folder this chat belongs to

#### ChatFolder Model
New model in `lib/data/model/chat/folder.dart`:
- `id`: Unique identifier
- `name`: Folder name
- `colorIndicator`: Optional color for the folder icon
- `isExpanded`: Whether the folder is expanded (default: true)

### Data Storage

#### FolderStore
- **Location**: `lib/data/store/folder.dart`
- **Purpose**: Manages folder persistence using Hive
- **Methods**:
  - `fetchAll()`: Load all folders
  - `put()`: Save a folder
  - `delete()`: Remove a folder

### UI Components

#### History List
- **Location**: `lib/view/page/home/history.dart`
- **Changes**:
  - Organized view with folders at top
  - "New Folder" button
  - Folder headers with expand/collapse
  - "Uncategorized" section for chats without folders
  - Context menu with all new actions

#### Chat List Items
- Visual indicators for pinned status (pin icon)
- Color indicators (left border)
- Comprehensive context menu with all actions

## Usage Guide

### Basic Workflow

1. **Creating a Folder**:
   - Click "New Folder" button
   - Enter folder name
   - Click OK

2. **Moving Chats to Folders**:
   - Click three dots on a chat
   - Select "Move to Folder"
   - Choose the destination folder

3. **Marking Important Chats**:
   - Pin frequently used chats (three dots → Pin)
   - Assign colors to categorize by type or priority (three dots → Set Color)

4. **Duplicating Chats**:
   - Click three dots on a chat
   - Select "Clone"
   - A copy will be created with " (Copy)" suffix

5. **Organizing Folders**:
   - Click on folder header to expand/collapse
   - Use folder menu (three dots) to rename or delete
   - Duplicate folders to create similar structures

## Benefits

1. **Better Organization**: Group related conversations together
2. **Quick Access**: Pin important chats to keep them at the top
3. **Visual Categorization**: Use colors to identify chat types at a glance
4. **Flexibility**: Clone chats for experimentation or backup
5. **Scalability**: Manage large numbers of chats efficiently with folders

## Future Enhancements (Potential)

- Drag and drop to reorder chats or move between folders
- Multi-select for batch operations
- Search within folders
- Folder colors and custom icons
- Export/import folder structures
- Nested folders (subfolders)
