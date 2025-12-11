import 'dart:math';

class FrasesIniciales {
  final List<String> frasesIniciales = [
    "La vida es lo que pasa mientras estás ocupado haciendo otros planes. – John Lennon",
    "El éxito es aprender a ir de fracaso en fracaso sin desesperarse. – Winston Churchill",
    "Sé el cambio que quieres ver en el mundo. – Mahatma Gandhi",
    "No cuentes los días, haz que los días cuenten. – Muhammad Ali",
    "El único modo de hacer un gran trabajo es amar lo que haces. – Steve Jobs",
    "La imaginación es más importante que el conocimiento. – Albert Einstein",
    "Nunca es tarde para ser lo que podrías haber sido. – George Eliot",
    "Hazlo o no lo hagas, pero no lo intentes. – Yoda",
  ];

  String generarFraseRandom() {
    final random = Random();
    return frasesIniciales[random.nextInt(frasesIniciales.length)];
  }
}
