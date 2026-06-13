import '../models/app_user.dart';

class PermissionService {
  const PermissionService(this.user);

  final AppUser user;

  bool get canUseStudentFeatures => user.isStudent || user.isFaculty || user.isAdmin;
  bool get canViewRoomStatus => user.isFaculty || user.isAdmin;
  bool get canAllocateRooms => user.isFaculty || user.isAdmin;
  bool get canViewStudents => user.isFaculty || user.isAdmin;
  bool get canManageStudents => user.isAdmin;
  bool get canManageFaculty => user.isAdmin;
  bool get canManageRooms => user.isAdmin;
  bool get canManageTimetables => user.isAdmin;
  bool get canResolveConflicts => user.isAdmin;

  bool canEditProfileField(String field) {
    if (user.isAdmin) return true;

    if (user.isStudent) {
      return field == 'email' || field == 'mobile';
    }

    if (user.isFaculty) {
      return field == 'email' || field == 'mobile';
    }

    return false;
  }
}
