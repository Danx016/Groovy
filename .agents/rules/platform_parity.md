# Paridad Obligatoria entre Plataformas (Windows & Android)

**REGLA CRÍTICA:**
Cualquier cambio solicitado en la aplicación debe aplicarse, respetarse y probarse siempre para **Windows y Android**.

1. **Diseño y Tipografía:**
   - La apariencia, tamaños de fuentes, botones, bordes y temas claros/oscuros deben ser consistentes en ambos sistemas operativos.
   - Las barras de navegación superiores (`AppBar`) deben mantener el tamaño compacto y estilizado (`fontSize: 20, fontWeight: FontWeight.w700`).

2. **Servicios y Motores:**
   - Lógica de búsqueda y carátulas de alta definición: sincronizar siempre entre `lib/services/ytdlp_service.dart` (Windows) y `android/app/src/main/python/ytdlp_helper.py` (Android).
   - Conectividad `Groovy Connect`: mantener la compatibilidad y paridad entre ambas plataformas a través del servidor.
