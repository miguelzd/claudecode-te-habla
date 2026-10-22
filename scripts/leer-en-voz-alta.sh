#!/usr/bin/env bash
# Hook Stop: lee la última respuesta de Claude y la dice en voz alta con `say`.
#
# Recibe por stdin el JSON del hook Stop, que incluye `.last_assistant_message`
# (texto plano del último mensaje de Claude).
#
# Voz y velocidad se cambian sin tocar este archivo, con dos variables en el
# bloque "env" de ~/.claude/settings.json (ver el README):
#   CLAUDE_TE_HABLA_VOZ        (por defecto: Paulina (Enhanced))
#   CLAUDE_TE_HABLA_VELOCIDAD  (palabras por minuto; por defecto: 185)

set -e

voz="${CLAUDE_TE_HABLA_VOZ:-Paulina (Enhanced)}"
velocidad="${CLAUDE_TE_HABLA_VELOCIDAD:-185}"

text=$(jq -r '.last_assistant_message // empty' 2>/dev/null)

[ -z "$text" ] && exit 0

# Limpiar markdown para que no se lea la sintaxis.
clean=$(printf '%s' "$text" | perl -0pe '
  s/```.*?```//gs;                  # bloques de código fenced
  s/`([^`]+)`/$1/g;                 # código inline
  s/^#+\s*//gm;                     # encabezados
  s/\*\*([^*]+)\*\*/$1/g;           # bold
  s/\*([^*]+)\*/$1/g;               # italic
  s/\[([^\]]+)\]\([^)]+\)/$1/g;     # links markdown
  s/^\s*[-*+]\s+/. /gm;             # bullets
  s/\|/ /g;                         # pipes de tablas
  s/-{3,}//g;                       # hrules
  s/\n{2,}/. /g;                    # párrafos a pausa
  # --- Estos dos van AL FINAL y no son cosmética: `say` los interpreta. ---
  # Un "<" suelto CORTA la lectura: say lo toma como apertura de marcado y
  # descarta todo lo que sigue (medido: 96 KB de audio pasan a 33 KB).
  s/<[^>]*>//g;                     # etiquetas completas
  s/[<>]/ /g;                       # signos sueltos
  # "[[ ... ]]" son comandos embebidos de say (silencios, tono, velocidad):
  # se borra el bloque entero, si no el contenido se lee en voz alta.
  s/\[\[[^\]]*\]\]//g;
  s/\[\[|\]\]/ /g;                  # restos sueltos
')

# Si una respuesta anterior aún se está leyendo, cortarla
# para que la nueva la reemplace en lugar de hacer cola.
# (pkill -f toma un patrón: se escapan los signos, por voces como "Paulina (Enhanced)").
patron=$(printf '%s' "say -v $voz" | sed 's/[][().*^$+?{}|\\]/\\&/g')
pkill -f "$patron" 2>/dev/null || true

# Hablar en background para no bloquear el hook.
say -v "$voz" -r "$velocidad" "$clean" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
