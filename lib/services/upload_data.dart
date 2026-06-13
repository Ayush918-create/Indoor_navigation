import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

Future<void> uploadInitialData() async {
  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://indoor-navigation-app-cfb2f-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  await database.ref().set({
    'users': {
      '101': {
        'userNo': '101',
        'name': 'Lucky Gupta',
        'password': '1234',
      }
    },
    'faculty': {
      'F1': {
        'name': 'Dr Sharma',
        'room': 'HOD Office',
        'available': true,
      },
      'F2': {
        'name': 'Dr Verma',
        'room': 'E1-102',
        'available': true,
      },
      'F3': {
        'name': 'Prof Mehta',
        'room': 'E1-105',
        'available': true,
      }
    },
    'timetable': {
      '1': {
        'day': 'Monday',
        'subject': 'Maths',
        'faculty': 'Dr Sharma',
        'room': 'E1-101',
        'startTime': '09:00',
        'endTime': '10:00',
      },
      '2': {
        'day': 'Monday',
        'subject': 'Physics',
        'faculty': 'Dr Verma',
        'room': 'E1-102',
        'startTime': '10:00',
        'endTime': '11:00',
      },
      '3': {
        'day': 'Tuesday',
        'subject': 'Data Structures',
        'faculty': 'Prof Mehta',
        'room': 'E1-103',
        'startTime': '09:00',
        'endTime': '10:30',
      },
      '4': {
        'day': 'Wednesday',
        'subject': 'Project Seminar',
        'faculty': 'Dr Sharma',
        'room': 'Seminar Hall',
        'startTime': '11:00',
        'endTime': '12:00',
      },
      '5': {
        'day': 'Thursday',
        'subject': 'Operating Systems',
        'faculty': 'Dr Verma',
        'room': 'E1-104',
        'startTime': '13:00',
        'endTime': '14:00',
      },
      '6': {
        'day': 'Friday',
        'subject': 'Computer Networks',
        'faculty': 'Prof Mehta',
        'room': 'E1-106',
        'startTime': '14:00',
        'endTime': '15:00',
      },
      '7': {
        'day': 'Saturday',
        'subject': 'Lab Session',
        'faculty': 'Dr Verma',
        'room': 'E1-108',
        'startTime': '10:00',
        'endTime': '12:00',
      },
    },
    'room_status': {
      'E1-101': {'occupied': false},
      'E1-102': {'occupied': false},
      'E1-103': {'occupied': false},
      'E1-104': {'occupied': false},
      'E1-105': {'occupied': false},
      'E1-106': {'occupied': false},
      'E1-107': {'occupied': false},
      'E1-108': {'occupied': false},
      'E1-109': {'occupied': false},
      'Seminar Hall': {'occupied': false},
      'HOD Office': {'occupied': false},
      'Lobby': {'occupied': false},
    },
  });

  // ignore: avoid_print
  print('Data Uploaded Successfully');
}
