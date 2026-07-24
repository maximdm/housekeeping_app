import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, ro }

class AppLocalizations extends ChangeNotifier {
  static AppLocalizations? _instance;
  AppLanguage _language = AppLanguage.en;

  AppLocalizations._();

  static AppLocalizations get instance {
    _instance ??= AppLocalizations._();
    return _instance!;
  }

  AppLanguage get language => _language;

  String get localeCode => _language == AppLanguage.en ? 'en' : 'ro';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'en';
    _language = saved == 'ro' ? AppLanguage.ro : AppLanguage.en;
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang == AppLanguage.ro ? 'ro' : 'en');
    notifyListeners();
  }

  String tr(String key) {
    final map = _language == AppLanguage.ro ? _ro : _en;
    return map[key] ?? key;
  }

  // Shorthand for context-based access
  static String of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)?.localeCode ?? 'en';
  }

  // ─── English Strings ──────────────────────────────────────
  static const _en = {
    // App
    'appTitle': 'Housekeeping App',
    'housekeeping': 'Housekeeping',

    // Login
    'signInToContinue': 'Sign in to continue',
    'yourName': 'Your Name',
    'password': 'Password',
    'pleaseSelectName': 'Please select your name',
    'pleaseEnterPassword': 'Please enter your password',
    'keepLoggedIn': 'Keep me logged in',
    'signIn': 'Sign In',
    'loginFailed': 'Login failed. Please try again.',
    'accountNotSetUp': 'This account is not set up for login. Contact your administrator.',
    'noStaffAccount': 'No staff account found. Contact your administrator.',

    // Navigation - Admin
    'overview': 'Overview',
    'rooms': 'Rooms',
    'staff': 'Staff',
    'chat': 'Chat',
    'notes': 'Notes',
    'aiChat': 'AI Chat',
    'dashboard': 'Dashboard',

    // Navigation - Staff
    'tasks': 'Tasks',

    // Common
    'toggleTheme': 'Toggle Theme',
    'signOut': 'Sign Out',
    'changePassword': 'Change Password',
    'lightMode': 'Light Mode',
    'darkMode': 'Dark Mode',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'save': 'Save',
    'edit': 'Edit',
    'add': 'Add',
    'close': 'Close',
    'done': 'Done',
    'none': 'None',
    'all': 'All',
    'none_': 'All',
    'loading': 'Loading...',
    'refresh': 'Refresh',
    'noItems': 'No items',
    'search': 'Search',
    'confirm': 'Confirm',
    'yes': 'Yes',
    'no': 'No',
    'name': 'Name',
    'role': 'Role',
    'status': 'Status',
    'actions': 'Actions',
    'back': 'Back',
    'next': 'Next',
    'create': 'Create',
    'update': 'Update',
    'filter': 'Filter',
    'selected': 'selected',
    'clear': 'Clear',

    // Overview / Dashboard
    'todayProgress': "Today's Progress",
    'cleanRooms': 'Clean Rooms',
    'needsCleaning': 'Needs Cleaning',
    'inProgress': 'In Progress',
    'skipped': 'Skipped',
    'recentActivity': 'Recent Activity',
    'priorityAttention': 'Priority Attention',
    'allClear': 'All clear! No priority issues.',
    'clearActivity': 'Clear Activity',
    'clearActivityConfirm': 'Delete all activity logs? This cannot be undone.',
    'activityCleared': 'Activity cleared',
    'noRecentActivity': 'No recent activity',
    'items': 'items',

    // Staff page
    'schedule': 'Schedule',
    'shifts': 'Shifts',
    'allStaff': 'All staff',
    'selectStaff': 'Select staff',
    'staffSelected': 'staff selected',
    'staffFilter': 'staff filter',
    'showingAllStaff': 'Showing all staff',
    'filterByStaff': 'Filter by Staff',
    'tapToSelectStaff': 'Tap to select staff',
    'noActiveStaff': 'No active staff',
    'selectShift': 'Select shift',
    'shiftSelected': 'Shift selected',
    'noShiftsDefined': 'No shifts defined. Add one below.',
    'shiftTypes': 'Shift Types',
    'noShiftsYet': 'No shifts defined',
    'shiftTypeCount': 'shift type(s)',
    'addShift': 'Add Shift',
    'editShift': 'Edit Shift',
    'newShift': 'New Shift',
    'shiftName': 'Shift Name',
    'startTime': 'Start Time',
    'endTime': 'End Time',
    'color': 'Color',
    'createShift': 'Create Shift',
    'saveChanges': 'Save Changes',
    'deleteShift': 'Delete Shift',
    'deleteShiftConfirm': 'Delete shift?',
    'assignments': 'assignments',
    'assignmentSaved': 'assignment(s) saved',
    'addStaff': 'Add Staff',
    'editProfile': 'Edit Profile',
    'activate': 'Activate',
    'deactivate': 'Deactivate',
    'deactivateStaff': 'Deactivate Staff',
    'deactivateStaffConfirm': 'Deactivate {name}? They will no longer be able to log in.',
    'deleteStaff': 'Delete Staff',
    'deleteStaffConfirm': 'Permanently delete {name}? This cannot be undone.',
    'deleted': 'deleted',
    'undo': 'Undo',
    'noShiftAssigned': 'No shift assigned',
    'noFloorAssigned': 'No floor assigned',
    'allFloors': 'All Floors',
    'allRoomTypes': 'All Room Types',
    'allStatuses': 'All Statuses',
    'addRoom': 'Add Room',
    'addFloor': 'Add Floor',
    'addRoomType': 'Add Room Type',
    'rooms_': 'Rooms',
    'floors': 'Floors',
    'roomTypes': 'Room Types',

    // Rooms page
    'roomsTitle': 'Rooms',
    'assign': 'Assign',
    'unassign': 'Unassign',
    'room': 'Room',
    'floor': 'Floor',
    'roomType': 'Room Type',
    'clean': 'Clean',
    'dirty': 'Dirty',

    // Room statuses
    'statusDirty': 'Dirty',
    'statusInProgress': 'In Progress',
    'statusClean': 'Clean',
    'statusSkipped': 'Skipped',

    // Room types
    'typeSingle': 'Single',
    'typeDouble': 'Double',
    'typeSuite': 'Suite',
    'typeTwin': 'Twin',
    'typeTriple': 'Triple',
    'typeDeluxe': 'Deluxe',
    'typeFamily': 'Family',
    'typeStandard': 'Standard',

    // Staff dashboard
    'todaysTasks': "Today's Tasks",
    'noTasksAssigned': 'No tasks assigned',
    'noRoomAssignments': 'You have no room assignments today',
    'noShiftsToday': 'No shift assigned today',

    // Staff rooms
    'myRooms': 'My Rooms',
    'allRooms': 'All Rooms',
    'assignedToMe': 'Assigned to Me',
    'notAssigned': 'Not Assigned',

    // Notes
    'notesTitle': 'Notes',
    'roomNotes': 'Room Notes',
    'toDo': 'To-Do',
    'sharedNotes': 'Shared Notes',
    'unread': 'Unread',
    'addNote': 'Add Note',
    'editNote': 'Edit Note',
    'deleteNote': 'Delete Note',
    'deleteNoteConfirm': 'Delete this note?',
    'noNotes': 'No notes',
    'noTodos': 'No to-do items',
    'addToDo': 'Add To-Do',
    'addToDoList': 'Add To-Do List',
    'newItem': 'New Item',
    'newList': 'New List',
    'listName': 'List Name',
    'noteTitle': 'Note Title',
    'noteContent': 'Note Content',
    'priority': 'Priority',
    'high': 'High',
    'medium': 'Medium',
    'low': 'Low',
    'forward': 'Forward',
    'sent': 'Sent',
    'received': 'Received',
    'noSentNotes': 'No sent notes',
    'newStaffNotesCount': '{count} new staff note(s)',

    // Staff notes
    'staffNotes': 'Staff Notes',
    'addStaffNote': 'Staff Note',
    'staffNoteSubtitle': 'Send a note to selected staff members',
    'sendTo': 'Send to',
    'from': 'From',
    'staffNoteSent': 'Note sent',
    'staffNoteDeleted': 'Note deleted',
    'deleteStaffNoteConfirm': 'Delete this staff note?',
    'noStaffNotes': 'No staff notes',
    'staffNotesEmptyHint': 'Create a staff note to send to your team',

    // Chat
    'chatTitle': 'Chat',
    'typeMessage': 'Type a message...',
    'send': 'Send',
    'deleteMessage': 'Delete Message',
    'deleteMessageConfirm': 'Delete this message?',
    'clearChat': 'Clear Chat',
    'clearChatConfirm': 'Clear all messages? This cannot be undone.',
    'chatHistory': 'Chat History',
    'noMessages': 'No messages yet',
    'today': 'Today',
    'yesterday': 'Yesterday',

    // AI Chat
    'aiChatTitle': 'AI Assistant',
    'aiPlaceholder': 'Ask me anything about the hotel...',
    'aiThinking': 'Thinking...',
    'aiError': 'Sorry, something went wrong.',
    'aiWelcome': 'Hello! I\'m your AI assistant. Ask me about rooms, staff, or anything hotel-related.',
    'aiHistory': 'AI History',

    // Change Password
    'changePasswordTitle': 'Change Password',
    'currentPassword': 'Current Password',
    'newPassword': 'New Password',
    'confirmPassword': 'Confirm Password',
    'passwordUpdated': 'Password updated successfully',
    'passwordMismatch': 'Passwords do not match',
    'passwordTooShort': 'Password must be at least 6 characters',

    // Room detail
    'roomDetail': 'Room Detail',
    'description': 'Description',
    'addDescription': 'Add a description...',
    'notes_': 'Notes',
    'todo_': 'To-Do',
    'markComplete': 'Mark Complete',
    'markIncomplete': 'Mark Incomplete',
    'skip': 'Skip',

    // Months
    'january': 'January',
    'february': 'February',
    'march': 'March',
    'april': 'April',
    'may': 'May',
    'june': 'June',
    'july': 'July',
    'august': 'August',
    'september': 'September',
    'october': 'October',
    'november': 'November',
    'december': 'December',

    // Days
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',

    // Floor/Room forms
    'floorName': 'Floor Name',
    'floorNumber': 'Floor Number',
    'roomNumber': 'Room Number',
    'selectFloor': 'Select Floor',
    'selectRoomType': 'Select Room Type',
    'typeName': 'Type Name',
    'capacity': 'Capacity',
    'createFloor': 'Create Floor',
    'createRoomType': 'Create Room Type',
    'createRoom': 'Create Room',
    'editRoom': 'Edit Room',
    'editFloor': 'Edit Floor',
    'editRoomType': 'Edit Room Type',

    // Staff form
    'staffUpdatedSuccessfully': 'Staff updated successfully',
    'staffLimitReached': 'Staff limit of {count} reached',
    'cleanerAccountCreated': 'Cleaner account created. They can log in by selecting their name — no password needed.',
    'failedToCreateStaff': 'Failed to create staff: {error}',
    'accountCreated': 'Account Created',
    'accountCreatedSuccess': '"{name}" has been created successfully.',
    'giveCredentials': 'Give these credentials to the staff member:',
    'accountLabel': 'Account: ',
    'accountNameCopied': 'Account name copied',
    'passwordLabel': 'Password: ',
    'passwordCopied': 'Password copied',
    'changePasswordAfterLogin': 'The staff member should change their password after first login.',
    'fullName': 'Full Name',
    'nameHint': 'e.g. John Smith',
    'pleaseEnterName': 'Please enter a name',
    'accountNameField': 'Account Name',
    'accountNameHint': 'e.g. staff001',
    'accountNameCannotBeChanged': 'Account name cannot be changed',
    'lettersNumbersOnly': 'Letters, numbers, and underscores only',
    'pleaseEnterAccountName': 'Please enter an account name',
    'mustBeAtLeast3': 'Must be at least 3 characters',
    'onlyLettersNumbersUnderscores': 'Only letters, numbers and underscores',
    'phoneNumberOptional': 'Phone Number (optional)',
    'accountsUsed': '{used} / {max} accounts used',
    'accountsLimitReached': 'Limit of {max} accounts reached',
    'resetPassword': 'Reset Password',
    'resetPasswordConfirm': 'Generate a new temporary password for {name}? They will need to use the new password on their next login.',
    'resetPasswordTitle': 'Reset Password',
    'newPasswordFor': 'New temporary password for {name}:',
    'failedToResetPassword': 'Failed to reset password',

    // Room form
    'pleaseEnterRoomNumber': 'Please enter a room number',
    'pleaseSelectRoomType': 'Please select a room type',
    'pleaseSelectFloor': 'Please select a floor',
    'descriptionOptional': 'Description (optional)',
    'descriptionHint': 'e.g. Corner room with sea view',

    // Room detail
    'roomStatusUpdated': 'Room status updated to {status}',
    'noRoomAssigned': 'No room assigned',
    'roomLabel': 'Room {number}',
    'addNoteHint': 'Add a note...',
    'deleteNoteQuestion': 'Delete note?',
    'thisActionUndone': 'This action can be undone.',
    'staffFallback': 'Staff',
    'noteDeleted': 'Note deleted',
    'setNoteStatus': 'Set status',
    'editNoteTitle': 'Edit Note',
    'noteTitleLabel': 'Title',
    'noteDescriptionLabel': 'Description',
    'noteUpdated': 'Note updated',
    'minutesAgo': '{minutes}m ago',
    'hoursAgo': '{hours}h ago',

    // Change password
    'passwordChangedSuccessfully': 'Password changed successfully',
    'failedToChangePassword': 'Failed to change password: {error}',
    'updateYourPassword': 'Update Your Password',
    'chooseStrongPassword': 'Choose a strong password that you haven\'t used before.',
    'pleaseEnterNewPassword': 'Please enter a new password',
    'pleaseConfirmPassword': 'Please confirm your password',

    // Admin chat
    'teamChat': 'Team Chat',
    'startConversation': 'Start a conversation with your team',
    'unknown': 'Unknown',

    // Assignment panel
    'assignedFloors': 'Assigned Floors',
    'noFloorsAssigned': 'No floors assigned for this date',
    'allFloorsAssigned': 'All floors already assigned for this date',
    'floorUnassigned': '{floor} unassigned',

    // Sharing
    'shareWithNone': 'Share with: None',
    'shareWithAll': 'Share with: All staff ({count})',
    'shareWithCustom': 'Share with: {count} staff members',
    'onlyAssignedStaff': 'Only assigned staff can see this',
    'shareWithAllStaff': 'Share with all {count} active staff members',
    'chooseSpecificStaff': 'Choose specific staff members',

    // Calendar presets
    'tomorrow': 'Tomorrow',
    'thisWeek': 'This Week',
    'weekdays': 'Weekdays',
    'next7Days': 'Next 7 Days',
    'nextWeek': 'Next Week',
    'thisMonth': 'This Month',
    'nextMonth': 'Next Month',
    'staffMember': 'Staff Member',
  };

  // ─── Romanian Strings ─────────────────────────────────────
  static const _ro = {
    // App
    'appTitle': 'Aplicatie Housekeeping',
    'housekeeping': 'Housekeeping',

    // Login
    'signInToContinue': 'Autentifica-te pentru a continua',
    'yourName': 'Numele tau',
    'password': 'Parola',
    'pleaseSelectName': 'Te rugam sa selectezi numele',
    'pleaseEnterPassword': 'Te rugam sa introduci parola',
    'keepLoggedIn': 'Ramane autentificat',
    'signIn': 'Autentificare',
    'loginFailed': 'Autentificare esuata. Te rugam sa incerci din nou.',
    'accountNotSetUp': 'Acest cont nu este configurat pentru autentificare. Contacteaza administratorul.',
    'noStaffAccount': 'Cont de angajat negasit. Contacteaza administratorul.',

    // Navigation - Admin
    'overview': 'Prezentare',
    'rooms': 'Camere',
    'staff': 'Personal',
    'chat': 'Chat',
    'notes': 'Notite',
    'aiChat': 'Chat AI',
    'dashboard': 'Panou de control',

    // Navigation - Staff
    'tasks': 'Sarcini',

    // Common
    'toggleTheme': 'Schimba tema',
    'signOut': 'Deconectare',
    'changePassword': 'Schimba parola',
    'lightMode': 'Mod luminos',
    'darkMode': 'Mod intunecat',
    'cancel': 'Anuleaza',
    'delete': 'Sterge',
    'save': 'Salveaza',
    'edit': 'Editeaza',
    'add': 'Adauga',
    'close': 'Inchide',
    'done': 'Gata',
    'none': 'Niciunul',
    'all': 'Toti',
    'none_': 'Tot',
    'loading': 'Se incarca...',
    'refresh': 'Reimprospateaza',
    'noItems': 'Niciun articol',
    'search': 'Cauta',
    'confirm': 'Confirma',
    'yes': 'Da',
    'no': 'Nu',
    'name': 'Nume',
    'role': 'Rol',
    'status': 'Status',
    'actions': 'Actiuni',
    'back': 'Inapoi',
    'next': 'Urmatorul',
    'create': 'Creaza',
    'update': 'Actualizeaza',
    'filter': 'Filtreaza',
    'selected': 'selectat',
    'clear': 'Goleste',

    // Overview / Dashboard
    'todayProgress': 'Progresul de azi',
    'cleanRooms': 'Camere curate',
    'needsCleaning': 'Necesita curatare',
    'inProgress': 'In desfasurare',
    'skipped': 'Sarite',
    'recentActivity': 'Activitate recenta',
    'priorityAttention': 'Atentie prioritara',
    'allClear': 'Totul e in regula! Nicio problema prioritara.',
    'clearActivity': 'Goleste activitatea',
    'clearActivityConfirm': 'Stergi toate jurnalele de activitate? Aceasta nu poate fi anulata.',
    'activityCleared': 'Activitatea a fost goalita',
    'noRecentActivity': 'Nicio activitate recenta',
    'items': 'elemente',

    // Staff page
    'schedule': 'Program',
    'shifts': 'Ture',
    'allStaff': 'Tot personalul',
    'selectStaff': 'Selecteaza personalul',
    'staffSelected': 'personal selectat',
    'staffFilter': 'filtru personal',
    'showingAllStaff': 'Se afiseaza tot personalul',
    'filterByStaff': 'Filtreaza dupa personal',
    'tapToSelectStaff': 'Apasa pentru a selecta personalul',
    'noActiveStaff': 'Niciun personal activ',
    'selectShift': 'Selecteaza tura',
    'shiftSelected': 'Tura selectata',
    'noShiftsDefined': 'Nicio tura definita. Adauga una mai jos.',
    'shiftTypes': 'Tipuri de ture',
    'noShiftsYet': 'Nicio tura definita',
    'shiftTypeCount': 'tip(uri) de tura',
    'addShift': 'Adauga tura',
    'editShift': 'Editeaza tura',
    'newShift': 'Tura noua',
    'shiftName': 'Numele turei',
    'startTime': 'Ora de inceput',
    'endTime': 'Ora de sfarsit',
    'color': 'Culoare',
    'createShift': 'Creaza tura',
    'saveChanges': 'Salveaza modificarile',
    'deleteShift': 'Sterge tura',
    'deleteShiftConfirm': 'Stergi tura?',
    'assignments': 'atribuiri',
    'assignmentSaved': 'atribuiri salvate',
    'addStaff': 'Adauga personal',
    'editProfile': 'Editeaza profilul',
    'activate': 'Activeaza',
    'deactivate': 'Dezactiveaza',
    'deactivateStaff': 'Dezactiveaza personal',
    'deactivateStaffConfirm': 'Dezactivezi pe {name}? Nu va mai putea sa se autentifice.',
    'deleteStaff': 'Sterge personal',
    'deleteStaffConfirm': 'Stergi permanent pe {name}? Aceasta nu poate fi anulata.',
    'deleted': 'sters',
    'undo': 'Anuleaza',
    'noShiftAssigned': 'Nicio tura atribuita',
    'noFloorAssigned': 'Niciun etaj atribuit',
    'allFloors': 'Toate etajele',
    'allRoomTypes': 'Toate tipurile',
    'allStatuses': 'Toate statusurile',
    'addRoom': 'Adauga camera',
    'addFloor': 'Adauga etaj',
    'addRoomType': 'Adauga tip camera',
    'rooms_': 'Camere',
    'floors': 'Etaje',
    'roomTypes': 'Tipuri camere',

    // Rooms page
    'roomsTitle': 'Camere',
    'assign': 'Atribuie',
    'unassign': 'Dezatribuie',
    'room': 'Camera',
    'floor': 'Etaj',
    'roomType': 'Tip camera',
    'clean': 'Curat',
    'dirty': 'Murdar',

    // Room statuses
    'statusDirty': 'Murdar',
    'statusInProgress': 'In desfasurare',
    'statusClean': 'Curat',
    'statusSkipped': 'Sarit',

    // Room types
    'typeSingle': 'Single',
    'typeDouble': 'Dubla',
    'typeSuite': 'Suite',
    'typeTwin': 'Twin',
    'typeTriple': 'Tripla',
    'typeDeluxe': 'Deluxe',
    'typeFamily': 'Familie',
    'typeStandard': 'Standard',

    // Staff dashboard
    'todaysTasks': 'Sarcinile de azi',
    'noTasksAssigned': 'Nicio sarcina atribuita',
    'noRoomAssignments': 'Nu ai atribuiri de camere astazi',
    'noShiftsToday': 'Nicio tura atribuita astazi',

    // Staff rooms
    'myRooms': 'Camerele mele',
    'allRooms': 'Toate camerele',
    'assignedToMe': 'Atribuite mie',
    'notAssigned': 'Neatribuite',

    // Notes
    'notesTitle': 'Notite',
    'roomNotes': 'Notite camera',
    'toDo': 'De facut',
    'sharedNotes': 'Notite partajate',
    'unread': 'Necitite',
    'addNote': 'Adauga notita',
    'editNote': 'Editeaza notita',
    'deleteNote': 'Sterge notita',
    'deleteNoteConfirm': 'Stergi aceasta notita?',
    'noNotes': 'Nicio notita',
    'noTodos': 'Niciun element de facut',
    'addToDo': 'Adauga de facut',
    'addToDoList': 'Adauga lista de facut',
    'newItem': 'Element nou',
    'newList': 'Lista noua',
    'listName': 'Numele listei',
    'noteTitle': 'Titlul notei',
    'noteContent': 'Continutul notei',
    'priority': 'Prioritate',
    'high': 'Ridicata',
    'medium': 'Medie',
    'low': 'Scazuta',
    'forward': 'Inainteaza',
    'sent': 'Trimise',
    'received': 'Primite',
    'noSentNotes': 'Nicio notita trimisa',
    'newStaffNotesCount': '{count} notita(e) de personal noi',

    // Staff notes
    'staffNotes': 'Notite personal',
    'addStaffNote': 'Notita personal',
    'staffNoteSubtitle': 'Trimite o notita catre personalul selectat',
    'sendTo': 'Trimite catre',
    'from': 'De la',
    'staffNoteSent': 'Notita trimisa',
    'staffNoteDeleted': 'Notita stearsa',
    'deleteStaffNoteConfirm': 'Stergi aceasta notita?',
    'noStaffNotes': 'Nicio notita de personal',
    'staffNotesEmptyHint': 'Creaza o notita de personal pentru echipa ta',

    // Chat
    'chatTitle': 'Chat',
    'typeMessage': 'Scrie un mesaj...',
    'send': 'Trimite',
    'deleteMessage': 'Sterge mesajul',
    'deleteMessageConfirm': 'Stergi acest mesaj?',
    'clearChat': 'Goleste chatul',
    'clearChatConfirm': 'Golesti toate mesajele? Aceasta nu poate fi anulata.',
    'chatHistory': 'Istoric chat',
    'noMessages': 'Niciun mesaj inca',
    'today': 'Astazi',
    'yesterday': 'Ieri',

    // AI Chat
    'aiChatTitle': 'Asistent AI',
    'aiPlaceholder': 'Intreaba-ma orice despre hotel...',
    'aiThinking': 'Gandesc...',
    'aiError': 'Scuze, a aparut o eroare.',
    'aiWelcome': 'Buna! Sunt asistentul tau AI. Intreaba-ma despre camere, personal sau orice legat de hotel.',
    'aiHistory': 'Istoric AI',

    // Change Password
    'changePasswordTitle': 'Schimba parola',
    'currentPassword': 'Parola curenta',
    'newPassword': 'Parola noua',
    'confirmPassword': 'Confirma parola',
    'passwordUpdated': 'Parola a fost actualizata cu succes',
    'passwordMismatch': 'Parolele nu coincid',
    'passwordTooShort': 'Parola trebuie sa aiba cel putin 6 caractere',

    // Room detail
    'roomDetail': 'Detalii camera',
    'description': 'Descriere',
    'addDescription': 'Adauga o descriere...',
    'notes_': 'Notite',
    'todo_': 'De facut',
    'markComplete': 'Marcheaza complet',
    'markIncomplete': 'Marcheaza incomplet',
    'skip': 'Sari',

    // Months
    'january': 'Ianuarie',
    'february': 'Februarie',
    'march': 'Martie',
    'april': 'Aprilie',
    'may': 'Mai',
    'june': 'Iunie',
    'july': 'Iulie',
    'august': 'August',
    'september': 'Septembrie',
    'october': 'Octombrie',
    'november': 'Noiembrie',
    'december': 'Decembrie',

    // Days
    'mon': 'Lun',
    'tue': 'Mar',
    'wed': 'Mie',
    'thu': 'Joi',
    'fri': 'Vin',
    'sat': 'Sam',
    'sun': 'Dum',

    // Floor/Room forms
    'floorName': 'Numele etajului',
    'floorNumber': 'Numarul etajului',
    'roomNumber': 'Numarul camerei',
    'selectFloor': 'Selecteaza etajul',
    'selectRoomType': 'Selecteaza tipul',
    'typeName': 'Numele tipului',
    'capacity': 'Capacitate',
    'createFloor': 'Creaza etaj',
    'createRoomType': 'Creaza tip camera',
    'createRoom': 'Creaza camera',
    'editRoom': 'Editeaza camera',
    'editFloor': 'Editeaza etajul',
    'editRoomType': 'Editeaza tipul',

    // Staff form
    'staffUpdatedSuccessfully': 'Personal actualizat cu succes',
    'staffLimitReached': 'Limita de {count} conturi atinsa',
    'cleanerAccountCreated': 'Contul de curatator creat. Se pot autentifica selectand numele — nu este necesara parola.',
    'failedToCreateStaff': 'Eroare la crearea contului: {error}',
    'accountCreated': 'Cont creat',
    'accountCreatedSuccess': '"{name}" a fost creat cu succes.',
    'giveCredentials': 'Ofera aceste date angajatului:',
    'accountLabel': 'Cont: ',
    'accountNameCopied': 'Numele contului a fost copiat',
    'passwordLabel': 'Parola: ',
    'passwordCopied': 'Parola a fost copiata',
    'changePasswordAfterLogin': 'Angajatul trebuie sa isi schimbe parola dupa prima autentificare.',
    'fullName': 'Nume complet',
    'nameHint': 'ex. Ion Popescu',
    'pleaseEnterName': 'Te rugam sa introduci un nume',
    'accountNameField': 'Nume cont',
    'accountNameHint': 'ex. staff001',
    'accountNameCannotBeChanged': 'Numele contului nu poate fi schimbat',
    'lettersNumbersOnly': 'Doar litere, cifre si underscore-uri',
    'pleaseEnterAccountName': 'Te rugam sa introduci un nume de cont',
    'mustBeAtLeast3': 'Trebuie sa aiba cel putin 3 caractere',
    'onlyLettersNumbersUnderscores': 'Doar litere, cifre si underscore-uri',
    'phoneNumberOptional': 'Numar de telefon (optional)',
    'accountsUsed': '{used} / {max} conturi folosite',
    'accountsLimitReached': 'Limita de {max} conturi atinsa',
    'resetPassword': 'Reseteaza parola',
    'resetPasswordConfirm': 'Generezi o parola temporara noua pentru {name}? Va trebui sa foloseasca parola noua la urmatoarea autentificare.',
    'resetPasswordTitle': 'Reseteaza parola',
    'newPasswordFor': 'Parola temporara noua pentru {name}:',
    'failedToResetPassword': 'Eroare la resetarea parolei',

    // Room form
    'pleaseEnterRoomNumber': 'Te rugam sa introduci numarul camerei',
    'pleaseSelectRoomType': 'Te rugam sa selectezi tipul camerei',
    'pleaseSelectFloor': 'Te rugam sa selectezi etajul',
    'descriptionOptional': 'Descriere (optional)',
    'descriptionHint': 'ex. Camera la colt cu vedere la mare',

    // Room detail
    'roomStatusUpdated': 'Statusul camerei actualizat la {status}',
    'noRoomAssigned': 'Nicio camera atribuita',
    'roomLabel': 'Camera {number}',
    'addNoteHint': 'Adauga o notita...',
    'deleteNoteQuestion': 'Stergi notita?',
    'thisActionUndone': 'Aceasta actiune nu poate fi anulata.',
    'staffFallback': 'Personal',
    'noteDeleted': 'Notita stearsa',
    'setNoteStatus': 'Seteaza status',
    'editNoteTitle': 'Editeaza notita',
    'noteTitleLabel': 'Titlu',
    'noteDescriptionLabel': 'Descriere',
    'noteUpdated': 'Notita actualizata',
    'minutesAgo': 'acum {minutes}m',
    'hoursAgo': 'acum {hours}h',

    // Change password
    'passwordChangedSuccessfully': 'Parola schimbata cu succes',
    'failedToChangePassword': 'Eroare la schimbarea parolei: {error}',
    'updateYourPassword': 'Actualizeaza parola',
    'chooseStrongPassword': 'Alege o parola puternica pe care nu ai mai folosit-o.',
    'pleaseEnterNewPassword': 'Te rugam sa introduci o parola noua',
    'pleaseConfirmPassword': 'Te rugam sa confirmi parola',

    // Admin chat
    'teamChat': 'Chat echipa',
    'startConversation': 'Incepe o conversatie cu echipa ta',
    'unknown': 'Necunoscut',

    // Assignment panel
    'assignedFloors': 'Etaje atribuite',
    'noFloorsAssigned': 'Niciun etaj atribuit pentru aceasta data',
    'allFloorsAssigned': 'Toate etajele sunt deja atribuite pentru aceasta data',
    'floorUnassigned': '{floor} dezatribuit',

    // Sharing
    'shareWithNone': 'Partajeaza cu: Nimeni',
    'shareWithAll': 'Partajeaza cu: Tot personalul ({count})',
    'shareWithCustom': 'Partajeaza cu: {count} membri',
    'onlyAssignedStaff': 'Doar personalul atribuit poate vedea acest lucru',
    'shareWithAllStaff': 'Partajeaza cu toti cei {count} activi',
    'chooseSpecificStaff': 'Alege membrii specifici',

    // Calendar presets
    'tomorrow': 'Maine',
    'thisWeek': 'Saptamana aceasta',
    'weekdays': 'Zile lucratoare',
    'next7Days': 'Urmatoarele 7 zile',
    'nextWeek': 'Saptamana viitoare',
    'thisMonth': 'Luna aceasta',
    'nextMonth': 'Luna viitoare',
    'staffMember': 'Membru personal',
  };
}

/// Convenience extension on BuildContext
extension LocalizedBuildContext on BuildContext {
  AppLocalizations get loc => Localizations.of<AppLocalizations>(this, AppLocalizations)!;
  String tr(String key) => loc.tr(key);
}
