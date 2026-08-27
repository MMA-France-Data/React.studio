import path from 'node:path';
import { ffmpeg } from '../src/lib/ffmpeg.js';
import { ensureDir } from '../src/lib/fsx.js';

/**
 * Fabrique une video source synthetique : trois plans nettement differents
 * (donc des changements de scene detectables) avec du son. Sert a faire
 * tourner le pipeline de bout en bout sans avoir a fournir un vrai clip.
 */
export async function makeSampleSource(outDir = 'out') {
  const file = path.join(await ensureDir(outDir), 'sample-source.mp4');

  const filters = [
    'color=c=0x2E7D32:s=720x1280:d=4,noise=alls=18:allf=t+u[a]',
    'testsrc2=s=720x1280:r=30:d=4[b]',
    'color=c=0xB71C1C:s=720x1280:d=4,geq=lum_expr=\'128+80*sin(2*PI*(X/120+T))\':cb_expr=128:cr_expr=180[c]',
    '[a][b][c]concat=n=3:v=1:a=0,fps=30,format=yuv420p[v]',
    'sine=frequency=220:duration=12,volume=0.25[au]',
  ];

  await ffmpeg([
    '-f', 'lavfi', '-i', 'nullsrc=s=16x16:d=1',
    '-filter_complex', filters.join(';'),
    '-map', '[v]', '-map', '[au]',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '128k',
    '-t', '12',
    file,
  ], 'video source de demonstration');

  return file;
}
