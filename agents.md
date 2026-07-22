# Housekeeping App - AI Agent Instructions

## 1. Project Overview
This is a dual-role Flutter application for hotel housekeeping management. 
It contains two distinct user experiences built from a single codebase:
- **Admin Dashboard:** A desktop/tablet-first management interface with persistent side navigation, looking ok on mobile.
    -the possibility to define rooms and floors, like single room,  double etc.
    -the possibility to add staff accounts with roles as cleaner and receptionist. theaccounts should not be tied to an email. For security,  I think a limit of 35 accounts should be implemented
- **Staff App:** A mobile-first, highly focused task execution interface for cleaners.
    -staus of the room, the add notes function, 
    -a chatroom for loged in users to comunicate
- **Other notes** If possible  the implementation of an ai chatbot, that could answer to  what  state are the  rooms in, what  needs cleaning etc. In the future  it should be able by a db of reservations to be  more helpfull.

## 2. Tech Stack & Key Packages
- **Framework:** Flutter (latest stable, Dart 3+)
- **Routing:** `routefly` (v3.1.3) - Folder-based routing.
- **Backend & Auth:** `supabase_flutter` - Authentication and real-time database streams.
- **Localdb** `sqflite` for storing cached db  when not connected to the network
- **UI Design System:** `forui` -preferable and in case you think it's needed Material 3 (M3).

## 3. UI (forui)
Minimalist nice looking design
- Use red  for accents
- keep the ui clean and visible
- use simple animations 


## 4. Routing Architecture (Routefly)
This project uses declarative, folder-based routing via `routefly`. 
- **DO NOT** use `Navigator.push` or `go_router`. 
- Always use `Routefly.navigate('/path')`.
- All routes live inside `lib/app/`.
- The main entry point uses the `@Main('lib/app')` annotation on the `MaterialApp.router`.

