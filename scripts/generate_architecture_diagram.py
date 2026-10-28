import math
import os

width = 960
height = 700
cx = 480
cy = 380

# Outer hexagon
R_out = 280
H_out = R_out * math.sqrt(3)

# Middle hexagon
R_mid = 195
H_mid = R_mid * math.sqrt(3)

# Inner hexagon
R_in = 110
H_in = R_in * math.sqrt(3)

def get_hex_points(r, h):
    pts = [
        (cx - r/2, cy - h/2),
        (cx + r/2, cy - h/2),
        (cx + r, cy),
        (cx + r/2, cy + h/2),
        (cx - r/2, cy + h/2),
        (cx - r, cy)
    ]
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)

pts_out = get_hex_points(R_out, H_out)
pts_mid = get_hex_points(R_mid, H_mid)
pts_in = get_hex_points(R_in, H_in)

# Arrow normal vectors (cos 30 = 0.866025, sin 30 = 0.5)
cos30 = math.cos(math.radians(30))
sin30 = math.sin(math.radians(30))

# For double-headed arrows, we leave a small gap of ~8px from the outer hexagon border
gap = 10
arrow_len = 80

# Top-Right arrow:
# Edge midpoint:
tr_ex = cx + 0.75 * R_out
tr_ey = cy - 0.25 * H_out
tr_x1 = tr_ex + gap * cos30
tr_y1 = tr_ey - gap * sin30
tr_x2 = tr_ex + arrow_len * cos30
tr_y2 = tr_ey - arrow_len * sin30

# Bottom-Right arrow:
br_ex = cx + 0.75 * R_out
br_ey = cy + 0.25 * H_out
br_x1 = br_ex
br_y1 = br_ey
br_x2 = br_ex + arrow_len * cos30
br_y2 = br_ey + arrow_len * sin30

# Bottom-Left arrow:
bl_ex = cx - 0.75 * R_out
bl_ey = cy + 0.25 * H_out
bl_x1 = bl_ex - gap * cos30
bl_y1 = bl_ey + gap * sin30
bl_x2 = bl_ex - arrow_len * cos30
bl_y2 = bl_ey + arrow_len * sin30

# Top-Left arrow:
tl_ex = cx - 0.75 * R_out
tl_ey = cy - 0.25 * H_out
tl_x1 = tl_ex
tl_y1 = tl_ey
tl_x2 = tl_ex - arrow_len * cos30
tl_y2 = tl_ey - arrow_len * sin30

# Top arrow:
t_x1 = cx
t_y1 = cy - 0.5 * H_out
t_x2 = cx
t_y2 = cy - 0.5 * H_out - 70

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" style="background: #ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <defs>
    <!-- Arrowhead forward marker -->
    <marker id="arrow" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6.5" markerHeight="6.5" orient="auto">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="#000000" />
    </marker>
    <!-- Arrowhead backward marker -->
    <marker id="arrow-start" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="6.5" markerHeight="6.5" orient="auto">
      <path d="M 8 1.5 L 0 5 L 8 8.5 z" fill="#000000" />
    </marker>
  </defs>

  <!-- ==================== HEXAGON LAYERS ==================== -->

  <!-- Outer Hexagon: Infraestructura (#C1E4F7) -->
  <polygon points="{pts_out}"
           fill="#C1E4F7" stroke="#000000" stroke-width="2.5" stroke-linejoin="round" />

  <!-- Middle Hexagon: Aplicación (#FFBBB1) -->
  <polygon points="{pts_mid}"
           fill="#FFBBB1" stroke="#000000" stroke-width="2.5" stroke-linejoin="round" />

  <!-- Inner Hexagon: Dominio (#FFECA9) -->
  <polygon points="{pts_in}"
           fill="#FFECA9" stroke="#000000" stroke-width="2.5" stroke-linejoin="round" />

  <!-- ==================== EXTERNAL ARROWS & LABELS ==================== -->

  <!-- 1. Top: HTTP (Single Arrow ->) -->
  <line x1="{t_x1:.1f}" y1="{t_y1:.1f}" x2="{t_x2:.1f}" y2="{t_y2:.1f}"
        stroke="#000000" stroke-width="2.2" marker-end="url(#arrow)" />
  <text x="{cx}" y="{t_y2 - 16:.1f}" text-anchor="middle" font-size="18" font-weight="600" fill="#000000">HTTP</text>

  <!-- 2. Top-Right: SQL (Double Arrow <->) -->
  <line x1="{tr_x1:.1f}" y1="{tr_y1:.1f}" x2="{tr_x2:.1f}" y2="{tr_y2:.1f}"
        stroke="#000000" stroke-width="2.2" marker-start="url(#arrow-start)" marker-end="url(#arrow)" />
  <text x="{tr_x2 + 16 * cos30:.1f}" y="{tr_y2 - 16 * sin30 + 4:.1f}"
        text-anchor="start" font-size="18" font-weight="600" fill="#000000">SQL</text>

  <!-- 3. Bottom-Right: Audio Driver (Single Arrow ->) -->
  <line x1="{br_x1:.1f}" y1="{br_ey:.1f}" x2="{br_x2:.1f}" y2="{br_y2:.1f}"
        stroke="#000000" stroke-width="2.2" marker-end="url(#arrow)" />
  <text x="{br_x2 + 16 * cos30:.1f}" y="{br_y2 + 16 * sin30 + 6:.1f}"
        text-anchor="start" font-size="18" font-weight="600" fill="#000000">Audio Driver</text>

  <!-- 4. Bottom-Left: Rest API (Double Arrow <->) -->
  <line x1="{bl_x1:.1f}" y1="{bl_y1:.1f}" x2="{bl_x2:.1f}" y2="{bl_y2:.1f}"
        stroke="#000000" stroke-width="2.2" marker-start="url(#arrow-start)" marker-end="url(#arrow)" />
  <text x="{bl_x2 - 16 * cos30:.1f}" y="{bl_y2 + 16 * sin30 + 6:.1f}"
        text-anchor="end" font-size="18" font-weight="600" fill="#000000">Rest API</text>

  <!-- 5. Top-Left: Message broker (Single Arrow ->) -->
  <line x1="{tl_x1:.1f}" y1="{tl_y1:.1f}" x2="{tl_x2:.1f}" y2="{tl_y2:.1f}"
        stroke="#000000" stroke-width="2.2" marker-end="url(#arrow)" />
  <text x="{tl_x2 - 16 * cos30:.1f}" y="{tl_y2 - 16 * sin30 + 4:.1f}"
        text-anchor="end" font-size="18" font-weight="600" fill="#000000">Message broker</text>

  <!-- ==================== OUTER HEXAGON LABELS ==================== -->

  <!-- Top Edge: Controladores -->
  <text x="{cx}" y="{cy - 0.5*H_out + 30:.1f}" text-anchor="middle" font-size="16" font-weight="500" fill="#000000">Controladores</text>

  <!-- Top-Right Edge: DatabaseAdapter -->
  <g transform="translate({cx + 0.5*(0.75*R_out + 0.75*R_mid) - 4:.1f}, {cy - 0.5*(0.25*H_out + 0.25*H_mid) + 2:.1f}) rotate(60)">
    <text x="0" y="4" text-anchor="middle" font-size="14.5" font-weight="500" fill="#000000">DatabaseAdapter</text>
  </g>

  <!-- Bottom-Right Edge: AudioPlayerAdapter -->
  <g transform="translate({cx + 0.5*(0.75*R_out + 0.75*R_mid) - 4:.1f}, {cy + 0.5*(0.25*H_out + 0.25*H_mid) - 2:.1f}) rotate(-60)">
    <text x="0" y="4" text-anchor="middle" font-size="14.5" font-weight="500" fill="#000000">AudioPlayerAdapter</text>
  </g>

  <!-- Bottom Edge: Infraestructura -->
  <text x="{cx}" y="{cy + 0.5*H_out - 22:.1f}" text-anchor="middle" font-size="19" font-weight="700" fill="#000000">Infraestructura</text>

  <!-- Bottom-Left Edge: RestClient -->
  <g transform="translate({cx - 0.5*(0.75*R_out + 0.75*R_mid) + 4:.1f}, {cy + 0.5*(0.25*H_out + 0.25*H_mid) - 2:.1f}) rotate(60)">
    <text x="0" y="4" text-anchor="middle" font-size="14.5" font-weight="500" fill="#000000">RestClient</text>
  </g>

  <!-- Top-Left Edge: GroovyConnectAdapter -->
  <g transform="translate({cx - 0.5*(0.75*R_out + 0.75*R_mid) + 4:.1f}, {cy - 0.5*(0.25*H_out + 0.25*H_mid) + 2:.1f}) rotate(-60)">
    <text x="0" y="4" text-anchor="middle" font-size="14" font-weight="500" fill="#000000">GroovyConnectAdapter</text>
  </g>

  <!-- ==================== MIDDLE HEXAGON LABELS ==================== -->

  <!-- Top: Casos de uso -->
  <text x="{cx}" y="{cy - 0.5*H_mid + 34:.1f}" text-anchor="middle" font-size="15" font-weight="500" fill="#000000">Casos de uso</text>

  <!-- Bottom: Aplicación -->
  <text x="{cx}" y="{cy + 0.5*H_mid - 24:.1f}" text-anchor="middle" font-size="18" font-weight="700" fill="#000000">Aplicación</text>

  <!-- ==================== INNER HEXAGON LABELS ==================== -->

  <!-- Entidades -->
  <text x="{cx}" y="{cy - 48}" text-anchor="middle" font-size="14" font-weight="500" fill="#000000">Entidades</text>

  <!-- Eventos -->
  <text x="{cx}" y="{cy - 22}" text-anchor="middle" font-size="14" font-weight="500" fill="#000000">Eventos</text>

  <!-- Dominio -->
  <text x="{cx}" y="{cy + 8}" text-anchor="middle" font-size="18" font-weight="800" fill="#000000">Dominio</text>

  <!-- Repositorios -->
  <text x="{cx}" y="{cy + 36}" text-anchor="middle" font-size="14" font-weight="500" fill="#000000">Repositorios</text>

  <!-- Servicios -->
  <text x="{cx}" y="{cy + 60}" text-anchor="middle" font-size="14" font-weight="500" fill="#000000">Servicios</text>

</svg>'''

os.makedirs('docs/architecture', exist_ok=True)
svg_path = 'docs/architecture/hexagonal_architecture.svg'
with open(svg_path, 'w', encoding='utf-8') as f:
    f.write(svg)

print(f"Generated {svg_path}")
