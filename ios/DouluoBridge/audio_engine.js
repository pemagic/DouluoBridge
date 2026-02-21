        // === Advanced Audio Synthesis Engine ===
        const AUDIO_ENGINE = {
            ctx: audioCtx,
            
            // 1. Guzheng (Zither): Plucked, resonant, slight vibrato
            playGuzheng(freq, time, dur) {
                if (!isFinite(freq)) return;
                const t = time;
                const osc = audioCtx.createOscillator();
                const osc2 = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                
                // Bright pluck (Triangle + harm)
                osc.type = 'triangle';
                osc2.type = 'sine';
                osc.frequency.setValueAtTime(freq, t);
                osc2.frequency.setValueAtTime(freq * 2, t);
                
                // Slight pitch bend (fingering)
                osc.frequency.linearRampToValueAtTime(freq, t + 0.1);
                
                // Envelope: Sharp attack, long sustain
                gain.gain.setValueAtTime(0, t);
                gain.gain.linearRampToValueAtTime(0.3, t + 0.02);
                gain.gain.exponentialRampToValueAtTime(0.001, t + dur * 2.0); // Long tail

                osc.connect(gain);
                osc2.connect(gain);
                gain.connect(audioCtx.destination);
                
                osc.start(t); osc.stop(t + dur * 2.0);
                osc2.start(t); osc2.stop(t + dur * 2.0);
            },

            // 2. Pipa (Lute): Sharp, metallic, staccato
            playPipa(freq, time) {
                if (!isFinite(freq)) return;
                const t = time;
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                
                osc.type = 'sawtooth'; // Rich harmonics
                osc.frequency.setValueAtTime(freq, t);
                
                // Filter for "wood" body resonance
                const filter = audioCtx.createBiquadFilter();
                filter.type = 'lowpass';
                filter.frequency.value = 3000;
                
                // Envelope: Instant attack, very short decay
                gain.gain.setValueAtTime(0, t);
                gain.gain.linearRampToValueAtTime(0.2, t + 0.005);
                gain.gain.exponentialRampToValueAtTime(0.001, t + 0.3);

                osc.connect(filter);
                filter.connect(gain);
                gain.connect(audioCtx.destination);
                
                osc.start(t); osc.stop(t + 0.3);
            },

            // 3. Dizi (Bamboo Flute): Breathy, vibrato, slide
            playDizi(freq, time, dur) {
                if (!isFinite(freq)) return;
                const t = time;
                const osc = audioCtx.createOscillator();
                const noise = audioCtx.createBufferSource();
                const gain = audioCtx.createGain();
                const noiseGain = audioCtx.createGain();
                
                // Tone
                osc.type = 'sine';
                osc.frequency.setValueAtTime(freq, t);
                
                // Vibrato (LFO)
                const vib = audioCtx.createOscillator();
                const vibGain = audioCtx.createGain();
                vib.frequency.value = 5;
                vibGain.gain.value = 6; // +/- 6Hz
                vib.connect(vibGain);
                vibGain.connect(osc.frequency);
                vib.start(t);

                // Breath noise
                const bufSize = audioCtx.sampleRate * 2;
                const buf = audioCtx.createBuffer(1, bufSize, audioCtx.sampleRate);
                const data = buf.getChannelData(0);
                for (let i = 0; i < bufSize; i++) data[i] = (Math.random() - 0.5) * 0.5;
                noise.buffer = buf;
                
                // Filter noise
                const nFilter = audioCtx.createBiquadFilter();
                nFilter.type = 'bandpass';
                nFilter.frequency.value = freq * 2;
                nFilter.Q.value = 1;

                // Envelope
                gain.gain.setValueAtTime(0, t);
                gain.gain.linearRampToValueAtTime(0.2, t + 0.1); // Slow attack
                gain.gain.setValueAtTime(0.15, t + dur - 0.1);
                gain.gain.linearRampToValueAtTime(0, t + dur);

                noiseGain.gain.setValueAtTime(0.05, t);
                noiseGain.gain.linearRampToValueAtTime(0, t + 0.2); // Attack breath

                osc.connect(gain);
                noise.connect(nFilter);
                nFilter.connect(noiseGain);
                noiseGain.connect(gain);
                gain.connect(audioCtx.destination);
                
                osc.start(t); osc.stop(t + dur);
                noise.start(t); noise.stop(t + dur);
            },

            // 4. Drum (War Drum): Impact
            playDrum(type, time) {
                const t = time;
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();

                if (type === 'kick') {
                    // Deep thud
                    osc.frequency.setValueAtTime(150, t);
                    osc.frequency.exponentialRampToValueAtTime(40, t + 0.1);
                    gain.gain.setValueAtTime(0.8, t);
                    gain.gain.exponentialRampToValueAtTime(0.01, t + 0.2);
                } else {
                    // Wood block / Rim
                    osc.type = 'square';
                    osc.frequency.setValueAtTime(800, t);
                    gain.gain.setValueAtTime(0.1, t);
                    gain.gain.exponentialRampToValueAtTime(0.01, t + 0.05);
                }

                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start(t); osc.stop(t + 0.2);
            }
        };
