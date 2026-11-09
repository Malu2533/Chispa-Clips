# ⚡ Chispa — clips virales con IA (MVP)

Chispa convierte un video largo en clips cortos listos para redes sociales, de forma 100 % local:
pega un enlace (YouTube, Vimeo, X, TikTok… vía **yt-dlp**) o sube un archivo, y Chispa:

1. **Descarga** el video en la mejor calidad disponible hasta 1080p (configurable a 4K) o usa el archivo subido.
2. **Transcribe** el audio con **faster-whisper** (modelo `small`, CPU, int8) con marcas de tiempo por palabra.
3. **Encuentra los mejores momentos** con un puntuador heurístico (sin API de LLM):
   gancho inicial (preguntas, exclamaciones, palabras gancho), energía de la voz (RMS),
   densidad de palabras clave (TF-IDF), ritmo (palabras/seg), emoción y coherencia
   (empieza y termina en frase completa). Cada clip recibe una puntuación 0–100 y un título.
4. **Recorta** cada clip con FFmpeg (libx264 `-crf 18 -preset fast`, AAC 192k, `+faststart`) en **ambos formatos**:
   - **Vertical 9:16** (recorte centrado; escalado a 1080×1920 por defecto)
   - **Horizontal 16:9** (encuadre y resolución originales; si la fuente es vertical se rellena con fondo desenfocado)
5. **Subtítulos incrustados**: **desactivados por defecto**. Se activan por proyecto (al crear o en
   "Re-exportar") o por clip (interruptor en cada tarjeta). Estilo animado con resaltado de la palabra actual (ASS).
6. Muestra el progreso por etapas, previsualiza cada clip en ambos formatos y ofrece descargas
   separadas en alta resolución (9:16 y 16:9), el **SRT de cada clip** y la transcripción completa en SRT.

Valores por defecto: **7 clips**, **60–80 s** cada uno, sin solaparse, cortados en bordes de frase/segmento.
Si el video es demasiado corto para 7 clips, se generan los que quepan y se muestra un aviso en español.

## Modo «En vivo» (YouTube, Twitch, Kick)

Pestaña **🔴 En vivo**: pega el enlace de un directo (`youtube.com/@canal/live` o `watch?v=…`, `twitch.tv/canal`, `kick.com/canal`).

1. Chispa comprueba que está en directo (**streamlink**; si no, **yt-dlp**). Si el enlace es una grabación (VOD), se procesa como video normal.
2. Graba la transmisión sin recodificar (mejor calidad hasta 1080p/1080p60) en **segmentos de 5 min** (3/5/10 configurables) con `ffmpeg -f segment`.
3. Cada segmento cerrado se transcribe (Whisper) y se añade a la transcripción global; el puntuador busca momentos de 60–80 s
   **sobre todo lo grabado**, así que un clip puede cruzar el borde entre segmentos (se cortan con `concat:` de los segmentos).
4. Los clips aparecen en la página mientras sigue el directo (vertical + horizontal, subtítulos desactivados por defecto),
   ordenados por puntuación; los **⭐ TOP 7** se destacan. Las puntuaciones se recalculan en cada segmento.
5. Límite: como mínimo 7 clips y **7 por hora** de directo (configurable), máx. 2 nuevos por segmento. «➕ Generar 3 clips más» añade más en cualquier momento.
6. **⏹ Detener** (o el fin del directo, el máximo de horas o <5 GB libres) cierra el último segmento, lo procesa y completa el TOP 7.

Grabaciones / VODs: pega el enlace en «Pegar enlace» (Twitch `twitch.tv/videos/…`, Kick `kick.com/canal/videos/<uuid>`,
directos pasados de YouTube). Para Kick, Chispa lee la API pública del video porque el extractor de yt-dlp devuelve 404.

## Ejecutar

```bash
cd /workspace/clipper
./run.sh                 # crea .venv si no existe e inicia en http://localhost:8000
# o en segundo plano:
nohup ./run.sh > server.log 2>&1 &
```

Requisitos del sistema: `ffmpeg` con libass, Python 3.10+, Node.js (yt-dlp lo usa para YouTube). `streamlink` se instala en el venv.
Dependencias Python en `requirements.txt`.

Variables de entorno opcionales:

| Variable | Defecto | Descripción |
|---|---|---|
| `PORT` | 8000 | Puerto HTTP |
| `CLIPPER_MODEL` | small | Modelo Whisper (`tiny`, `base`, `small`, `medium`…) |
| `CLIPPER_CRF` | 18 | Calidad x264 (menor = mejor) |
| `CLIPPER_PRESET` | fast | Preset x264 (`veryfast` = más rápido, `medium`/`slow` = algo más compresión) |
| `CLIPPER_MAX_HEIGHT` | 1080 | Resolución máxima a descargar por enlace (2160 = 4K; mucho más lento) |
| `CLIPPER_DATA` | ./data | Carpeta de trabajos |
| `CLIPPER_LIVE_PRESET` | veryfast | Preset x264 de los clips en vivo |
| `CLIPPER_MODEL_IDLE` | 600 | Segundos sin uso tras los que se descarga Whisper de la RAM |
| `CLIPPER_LIVE_MIN_FREE_GB` | 5 | Detiene la grabación si queda menos disco |

## Acceso con contraseña / modo público

- Si existe la variable `CHISPA_PASSWORD`, **toda** la app (páginas, API, vídeos y descargas) exige iniciar sesión
  en `/login` (cookie de sesión firmada, HttpOnly, 7 días; `/logout` para salir). Sin la variable, la app queda abierta (uso local).
- `./run-public.sh` activa el modo público (`CHISPA_PUBLIC=1`) y **se niega a arrancar** si `CHISPA_PASSWORD` no está definida.
- Límite de intentos: 10 fallos por IP en 10 minutos (usa `CF-Connecting-IP` detrás de Cloudflare).
- Las subidas se envían en **fragmentos de 50 MB** (`/api/uploads`), así funcionan detrás de túneles/proxys con límite
  de ~100 MB por petición (p. ej. Cloudflare). Para videos muy grandes, pegar el enlace sigue siendo lo más rápido.

Túnel temporal (si la red lo permite):

```bash
nohup cloudflared tunnel --no-autoupdate --protocol http2 --url http://localhost:8000 > tunnel.log 2>&1 &
grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' tunnel.log
```

### Enlace público con ngrok (activo)

URL fija (dominio estático gratuito de la cuenta): **https://unbundle-kindling-essential.ngrok-free.dev**

```bash
./run-public.sh &        # app con contraseña
./start-ngrok.sh         # túnel ngrok -> puerto 8000 (log en ngrok.log)
```

- La config de ngrok usa `agent.crl_noverify: true` porque el proxy de salida de esta máquina rompe la descarga del CRL de ngrok.
- El plan gratuito muestra primero una página de aviso de ngrok ("You are about to visit…") en navegadores: pulsa **Visit Site** una vez.

## API

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/uploads` | Inicia subida por fragmentos (`filename`, `size`) → `upload_id`, `chunk_size` |
| PUT | `/api/uploads/{id}?offset=N` | Cuerpo binario del fragmento |
| POST | `/api/jobs` | multipart: `url`, `upload_id` o `file`, `formats` (`vertical,horizontal`), `captions` (false), `num_clips` (7), `min_len` (60), `max_len` (80), `language` (auto), `upscale` (true) |
| POST | `/api/live` | Directo: `url`, `per_hour` (7), `chunk_minutes` (5), `max_hours` (4) + opciones de clips |
| POST | `/api/jobs/{id}/stop` | Detener grabación |
| POST | `/api/jobs/{id}/more` | Generar `n` clips más (directos) |
| GET | `/api/jobs` | Lista de proyectos |
| GET | `/api/jobs/{id}` | Estado, progreso, clips y renders |
| POST | `/api/jobs/{id}/rerender` | Re-exportar todos los clips (`formats`, `captions`) |
| POST | `/api/jobs/{id}/clips/{n}/rerender` | Activar/desactivar subtítulos de un clip (`captions`) |
| DELETE | `/api/jobs/{id}` | Borrar proyecto |
| GET | `/media/{id}/{archivo}?download=1` | Descargar MP4/SRT (sin `download` = vista previa con soporte Range) |

## Estructura

```
app/main.py       FastAPI (rutas, subida por fragmentos, descargas)
app/auth.py       login con contraseña y cookie de sesión
app/live.py       grabación de directos por segmentos + clips incrementales
app/pipeline.py   descarga, transcripción, render FFmpeg, cola de trabajos
app/scoring.py    puntuador heurístico de momentos + títulos
app/captions.py   generación de SRT y ASS (subtítulos animados)
static/           SPA (HTML/CSS/JS, tema oscuro)
data/jobs/<id>/   archivos de cada proyecto (source, clips, srt, job.json)
```

## Limitaciones conocidas

- **En vivo**: el primer clip tarda ≈ duración del segmento + transcripción (~20–30 s) + exportación (~1–2 min) → **~7 min** con segmentos de 5 min.
  Todo corre en CPU y un paso pesado a la vez: un directo 1080p60 se sigue en tiempo real; **varios directos a la vez se retrasan** (se procesa la cola al detener).
  Los clips en vivo usan `-preset veryfast` (CRF 18) para ir al ritmo. Disco: ~1,5–4 GB por hora de grabación a 1080p (los segmentos se guardan para «Generar más»).
  Si el servidor se reinicia, la grabación se detiene (los clips hechos se conservan). Directos sin voz (música) usan solo la energía del audio.
  Los anuncios de Twitch se omiten (streamlink), lo que puede dejar pequeños saltos.

- **CPU**: todo corre en CPU. Whisper `small` transcribe aprox. 10–20× tiempo real en 8 núcleos;
  el cuello de botella es la codificación x264 (2 formatos × N clips, `-crf 18 -preset medium`).
- **Puntuador heurístico**: no "entiende" el contenido como un LLM; prioriza ganchos, energía y palabras clave.
  Los títulos son la frase más representativa del clip (no reescritos).
- **Reencuadre vertical**: recorte centrado fijo (sin seguimiento de caras/hablante).
- **Descargas por enlace**: algunos sitios bloquean descargas (YouTube puede pedir "inicia sesión / no eres un bot"
  desde IPs de centros de datos, Instagram/Facebook suelen requerir login, contenido con DRM no es compatible).
  Solución: descargar el video y subirlo como archivo.
- La resolución final depende de la fuente (si el original es 720p, el 16:9 sale en 720p; el 9:16 se escala a 1080×1920).
- Un solo trabajo se procesa a la vez (cola). La protección es una sola contraseña compartida (sin cuentas de usuario).
- Si el servidor se reinicia a mitad de un trabajo, ese trabajo queda marcado como error.
