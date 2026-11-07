import './globals.css';
import { Newsreader, Hanken_Grotesk } from 'next/font/google';

const serif = Newsreader({ subsets: ['latin'], variable: '--font-serif', display: 'swap' });
const sans = Hanken_Grotesk({ subsets: ['latin'], variable: '--font-sans', display: 'swap' });

export const metadata = { title: 'Club Deportivo Doctores' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={`${serif.variable} ${sans.variable}`}>
      <body>
        <main>{children}</main>
      </body>
    </html>
  );
}
