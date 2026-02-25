package com.douluo.bridge

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AndroidAudioManager(private val context: Context) {
    
    private var bgmRunnable: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())
    
    private var bgmBpm: Float = 100f
    private var bgmSongId: Int = 0
    private var bgmBeat: Int = 0
    
    private val sampleRate = 44100
    
    // Pentatonic Scale
    private val scale = mapOf(
        "G3" to 196f, "A3" to 220f, "B3" to 247f, "D4" to 293f, "E4" to 330f,
        "G4" to 392f, "A4" to 440f, "B4" to 494f, "D5" to 587f, "E5" to 659f,
        "G5" to 784f, "A5" to 880f, "B5" to 988f, "D6" to 1175f, "E6" to 1318f
    )
    
    // Note format: Pair(NoteName, DurationIn16thNotes)
    private val songs = listOf(
        // Lv1: Heroic
        listOf(Pair("E5", 2), Pair("D5", 2), Pair("B4", 2), Pair("A4", 2), Pair("G4", 4), Pair("rest", 2),
               Pair("B4", 2), Pair("A4", 2), Pair("G4", 2), Pair("E4", 2), Pair("D4", 4), Pair("rest", 2),
               Pair("G4", 2), Pair("A4", 2), Pair("B4", 4), Pair("D5", 4), Pair("E5", 8),
               Pair("D5", 2), Pair("B4", 2), Pair("A4", 4), Pair("G4", 4), Pair("rest", 2),
               Pair("E4", 2), Pair("G4", 2), Pair("A4", 2), Pair("B4", 4), Pair("D5", 4),
               Pair("E5", 2), Pair("D5", 2), Pair("B4", 2), Pair("G4", 2), Pair("A4", 8),
               Pair("G4", 2), Pair("A4", 2), Pair("B4", 2), Pair("D5", 2), Pair("E5", 4), Pair("G5", 4),
               Pair("E5", 2), Pair("D5", 2), Pair("B4", 4), Pair("A4", 2), Pair("G4", 2), Pair("E4", 4),
               Pair("D4", 2), Pair("E4", 2), Pair("G4", 4), Pair("A4", 4), Pair("B4", 8),
               Pair("D5", 2), Pair("E5", 2), Pair("G5", 4), Pair("E5", 2), Pair("D5", 2), Pair("B4", 4),
               Pair("A4", 2), Pair("G4", 2), Pair("E4", 2), Pair("D4", 2), Pair("G4", 8)),

        // Lv2: Carefree
        listOf(Pair("G4", 2), Pair("A4", 2), Pair("B4", 4), Pair("D5", 2), Pair("E5", 2), Pair("G5", 4),
               Pair("E5", 2), Pair("D5", 2), Pair("B4", 4), Pair("rest", 2),
               Pair("A4", 2), Pair("B4", 2), Pair("D5", 4), Pair("G4", 4), Pair("rest", 2),
               Pair("G4", 2), Pair("B4", 2), Pair("D5", 2), Pair("E5", 4), Pair("D5", 2), Pair("B4", 2),
               Pair("A4", 4), Pair("G4", 4), Pair("rest", 2),
               Pair("E5", 2), Pair("D5", 2), Pair("B4", 2), Pair("A4", 2), Pair("G4", 4), Pair("rest", 2),
               Pair("D5", 2), Pair("E5", 2), Pair("G5", 4), Pair("E5", 2), Pair("D5", 2), Pair("B4", 8),
               Pair("G4", 2), Pair("A4", 2), Pair("B4", 2), Pair("D5", 2), Pair("E5", 4), Pair("G5", 4),
               Pair("A5", 2), Pair("G5", 2), Pair("E5", 4), Pair("D5", 2), Pair("B4", 2), Pair("A4", 4),
               Pair("G4", 2), Pair("A4", 2), Pair("B4", 4), Pair("D5", 8),
               Pair("B4", 2), Pair("A4", 2), Pair("G4", 4), Pair("E4", 2), Pair("G4", 2), Pair("A4", 8)),

        // Lv3: Martial
        listOf(Pair("D5", 1), Pair("E5", 1), Pair("G5", 2), Pair("E5", 1), Pair("D5", 1), Pair("B4", 2),
               Pair("A4", 1), Pair("B4", 1), Pair("D5", 2), Pair("G4", 4),
               Pair("B4", 2), Pair("A4", 2), Pair("G4", 4), Pair("D4", 2), Pair("E4", 2),
               Pair("G4", 1), Pair("A4", 1), Pair("B4", 2), Pair("D5", 1), Pair("E5", 1), Pair("G5", 2),
               Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("A4", 4), Pair("rest", 2),
               Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 1), Pair("A4", 2), Pair("G4", 2),
               Pair("B4", 1), Pair("D5", 1), Pair("E5", 2), Pair("G5", 4), Pair("rest", 2),
               Pair("A4", 1), Pair("B4", 1), Pair("D5", 1), Pair("E5", 1), Pair("G5", 2), Pair("A5", 2),
               Pair("G5", 1), Pair("E5", 1), Pair("D5", 2), Pair("B4", 4), Pair("G4", 4),
               Pair("D5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 1), Pair("A4", 2), Pair("G4", 2),
               Pair("E4", 2), Pair("D4", 2), Pair("G4", 8)),

        // Lv4: Ambush
        listOf(Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 1), Pair("A4", 2), Pair("G4", 2),
               Pair("E4", 1), Pair("D4", 1), Pair("G3", 2), Pair("A3", 4), Pair("rest", 2),
               Pair("D5", 2), Pair("E5", 2), Pair("G5", 4), Pair("rest", 2),
               Pair("A5", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("A4", 2),
               Pair("G4", 1), Pair("A4", 1), Pair("B4", 2), Pair("D5", 4), Pair("rest", 2),
               Pair("G5", 1), Pair("E5", 1), Pair("G5", 1), Pair("A5", 1), Pair("G5", 2), Pair("E5", 2),
               Pair("D5", 1), Pair("B4", 1), Pair("A4", 2), Pair("G4", 4), Pair("rest", 2),
               Pair("E4", 1), Pair("G4", 1), Pair("A4", 1), Pair("B4", 1), Pair("D5", 2), Pair("E5", 2),
               Pair("G5", 1), Pair("A5", 1), Pair("G5", 2), Pair("E5", 4), Pair("D5", 4),
               Pair("B4", 1), Pair("A4", 1), Pair("G4", 2), Pair("E4", 2), Pair("D4", 2), Pair("G3", 4),
               Pair("A3", 2), Pair("D4", 2), Pair("E4", 2), Pair("G4", 2), Pair("A4", 8)),

        // Lv5: Archery
        listOf(Pair("E5", 2), Pair("G5", 2), Pair("A5", 4), Pair("G5", 2), Pair("E5", 2), Pair("D5", 4),
               Pair("B4", 2), Pair("D5", 2), Pair("E5", 4), Pair("rest", 2),
               Pair("G4", 4), Pair("A4", 4), Pair("B4", 4), Pair("rest", 2),
               Pair("D5", 2), Pair("E5", 2), Pair("G5", 2), Pair("A5", 2), Pair("G5", 4), Pair("E5", 4),
               Pair("D5", 2), Pair("B4", 2), Pair("A4", 4), Pair("G4", 4), Pair("rest", 2),
               Pair("B4", 2), Pair("D5", 2), Pair("E5", 4), Pair("G5", 2), Pair("A5", 2), Pair("B5", 4),
               Pair("A5", 2), Pair("G5", 2), Pair("E5", 4), Pair("D5", 2), Pair("B4", 2), Pair("A4", 4),
               Pair("G4", 2), Pair("A4", 2), Pair("B4", 2), Pair("D5", 2), Pair("E5", 8),
               Pair("G5", 2), Pair("E5", 2), Pair("D5", 4), Pair("B4", 2), Pair("A4", 2), Pair("G4", 4),
               Pair("E4", 2), Pair("G4", 2), Pair("A4", 4), Pair("B4", 8)),

        // Lv6: Blades
        listOf(Pair("G5", 1), Pair("rest", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 2), Pair("B4", 2),
               Pair("G4", 1), Pair("rest", 1), Pair("G4", 1), Pair("A4", 1), Pair("B4", 4),
               Pair("D5", 2), Pair("E5", 2), Pair("G5", 2), Pair("rest", 2),
               Pair("A5", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("rest", 2),
               Pair("G4", 1), Pair("A4", 1), Pair("B4", 1), Pair("D5", 1), Pair("E5", 2), Pair("G5", 2),
               Pair("E5", 1), Pair("rest", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("A4", 2),
               Pair("G4", 1), Pair("A4", 1), Pair("B4", 2), Pair("D5", 4), Pair("rest", 2),
               Pair("G5", 1), Pair("A5", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 2), Pair("B4", 2),
               Pair("A4", 1), Pair("B4", 1), Pair("D5", 1), Pair("E5", 1), Pair("G5", 4), Pair("rest", 2),
               Pair("D5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 1), Pair("A4", 2), Pair("G4", 2),
               Pair("E4", 1), Pair("G4", 1), Pair("A4", 2), Pair("B4", 4), Pair("D5", 8)),

        // Lv7: Dragon Tiger
        listOf(Pair("B4", 1), Pair("D5", 1), Pair("E5", 1), Pair("G5", 1), Pair("A5", 2), Pair("G5", 2),
               Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("G4", 4),
               Pair("A4", 2), Pair("B4", 2), Pair("D5", 2), Pair("E5", 2), Pair("G5", 4), Pair("rest", 2),
               Pair("A5", 1), Pair("G5", 1), Pair("E5", 2), Pair("D5", 1), Pair("B4", 1), Pair("A4", 2),
               Pair("G4", 2), Pair("A4", 2), Pair("B4", 4), Pair("D5", 4), Pair("rest", 2),
               Pair("E5", 1), Pair("G5", 1), Pair("A5", 2), Pair("G5", 1), Pair("E5", 1), Pair("D5", 2),
               Pair("B4", 1), Pair("A4", 1), Pair("G4", 2), Pair("E4", 4), Pair("rest", 2),
               Pair("G4", 1), Pair("A4", 1), Pair("B4", 1), Pair("D5", 1), Pair("E5", 2), Pair("G5", 2),
               Pair("A5", 2), Pair("G5", 2), Pair("E5", 4), Pair("D5", 2), Pair("B4", 2),
               Pair("A4", 1), Pair("B4", 1), Pair("D5", 2), Pair("E5", 4), Pair("G5", 8),
               Pair("E5", 2), Pair("D5", 2), Pair("B4", 4), Pair("A4", 2), Pair("G4", 2), Pair("E4", 8)),

        // Lv8: Moon Reflected
        listOf(Pair("G5", 3), Pair("E5", 1), Pair("D5", 2), Pair("B4", 2), Pair("A4", 4),
               Pair("G4", 2), Pair("A4", 1), Pair("B4", 1), Pair("D5", 4), Pair("rest", 2),
               Pair("B4", 2), Pair("A4", 2), Pair("G4", 4), Pair("E4", 2), Pair("D4", 2), Pair("G3", 4),
               Pair("rest", 2), Pair("A3", 2), Pair("D4", 2), Pair("E4", 2), Pair("G4", 4),
               Pair("A4", 3), Pair("G4", 1), Pair("E4", 2), Pair("D4", 2), Pair("G4", 4), Pair("rest", 2),
               Pair("B4", 2), Pair("D5", 2), Pair("E5", 3), Pair("D5", 1), Pair("B4", 2), Pair("A4", 2),
               Pair("G4", 4), Pair("A4", 2), Pair("B4", 2), Pair("D5", 4), Pair("rest", 2),
               Pair("E5", 3), Pair("D5", 1), Pair("B4", 2), Pair("A4", 2), Pair("G4", 4),
               Pair("E4", 2), Pair("G4", 2), Pair("A4", 3), Pair("G4", 1), Pair("E4", 4), Pair("D4", 4),
               Pair("G3", 2), Pair("A3", 2), Pair("D4", 4), Pair("E4", 2), Pair("G4", 2), Pair("A4", 8)),

        // Lv9: Ethereal
        listOf(Pair("G5", 4), Pair("E5", 4), Pair("D5", 4), Pair("B4", 4),
               Pair("G4", 4), Pair("A4", 4), Pair("B4", 8),
               Pair("D5", 4), Pair("E5", 4), Pair("G5", 8), Pair("rest", 4),
               Pair("A5", 4), Pair("G5", 4), Pair("E5", 4), Pair("D5", 4),
               Pair("B4", 4), Pair("A4", 4), Pair("G4", 8), Pair("rest", 4),
               Pair("E4", 4), Pair("G4", 4), Pair("A4", 4), Pair("B4", 4),
               Pair("D5", 4), Pair("E5", 4), Pair("G5", 4), Pair("A5", 4),
               Pair("G5", 4), Pair("E5", 4), Pair("D5", 8),
               Pair("B4", 4), Pair("D5", 4), Pair("E5", 4), Pair("G5", 4),
               Pair("A5", 4), Pair("G5", 4), Pair("E5", 4), Pair("D5", 4), Pair("B4", 8)),

        // Lv10: Plum Blossom
        listOf(Pair("E6", 2), Pair("D6", 2), Pair("B5", 4), Pair("A5", 2), Pair("G5", 2), Pair("E5", 4),
               Pair("G5", 2), Pair("A5", 2), Pair("B5", 8), Pair("rest", 2),
               Pair("E5", 2), Pair("D5", 2), Pair("G4", 4), Pair("A4", 2), Pair("B4", 2), Pair("D5", 4),
               Pair("E5", 2), Pair("G5", 2), Pair("A5", 4), Pair("G5", 2), Pair("E5", 2), Pair("D5", 4),
               Pair("B4", 2), Pair("A4", 2), Pair("G4", 4), Pair("rest", 2),
               Pair("D6", 2), Pair("B5", 2), Pair("A5", 4), Pair("G5", 2), Pair("E5", 2), Pair("D5", 4),
               Pair("E5", 2), Pair("G5", 2), Pair("A5", 2), Pair("B5", 2), Pair("D6", 4), Pair("rest", 2),
               Pair("E6", 2), Pair("D6", 2), Pair("B5", 2), Pair("A5", 2), Pair("G5", 4), Pair("E5", 4),
               Pair("D5", 2), Pair("E5", 2), Pair("G5", 4), Pair("A5", 2), Pair("G5", 2), Pair("E5", 4),
               Pair("D5", 2), Pair("B4", 2), Pair("A4", 4), Pair("G4", 2), Pair("A4", 2), Pair("B4", 8)),

        // Boss Battle: Intense, fast-paced combat melody (index 10, BPM 160)
        listOf(Pair("G5", 1), Pair("E5", 1), Pair("G5", 1), Pair("A5", 1), Pair("G5", 2), Pair("E5", 1), Pair("D5", 1),
               Pair("B4", 2), Pair("D5", 1), Pair("E5", 1), Pair("G5", 2), Pair("rest", 1),
               Pair("A5", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 1), Pair("A4", 2), Pair("G4", 2),
               Pair("rest", 1), Pair("B4", 1), Pair("D5", 1), Pair("E5", 1), Pair("G5", 2), Pair("A5", 2),
               Pair("G5", 1), Pair("E5", 1), Pair("D5", 2), Pair("B4", 1), Pair("A4", 1), Pair("G4", 2),
               Pair("A4", 1), Pair("B4", 1), Pair("D5", 2), Pair("E5", 2), Pair("G5", 4),
               Pair("A5", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("A4", 1), Pair("B4", 1),
               Pair("D5", 2), Pair("E5", 1), Pair("G5", 1), Pair("A5", 2), Pair("G5", 2),
               Pair("E5", 1), Pair("D5", 1), Pair("B4", 2), Pair("A4", 2), Pair("G4", 4),
               Pair("D5", 1), Pair("E5", 1), Pair("G5", 1), Pair("A5", 1), Pair("G5", 1), Pair("E5", 1), Pair("D5", 1), Pair("B4", 1),
               Pair("A4", 2), Pair("B4", 2), Pair("D5", 2), Pair("E5", 2), Pair("G5", 8))
    )

    fun startBGM(songId: Int, bpm: Float) {
        stopBGM()
        bgmSongId = Math.max(0, Math.min(songId, songs.size - 1))
        bgmBpm = bpm
        bgmBeat = 0
        
        val intervalMs = (60.0 / bpm / 4.0 * 1000.0).toLong()
        
        bgmRunnable = object : Runnable {
            override fun run() {
                scheduleBGMNote()
                handler.postDelayed(this, intervalMs)
            }
        }
        handler.post(bgmRunnable!!)
    }

    fun stopBGM() {
        bgmRunnable?.let { handler.removeCallbacks(it) }
        bgmRunnable = null
    }

    fun changeSong(songId: Int, bpm: Float) {
        startBGM(songId, bpm)
    }

    private fun scheduleBGMNote() {
        val song = songs[bgmSongId]
        
        var acc = 0
        var noteIndex = 0
        for (i in song.indices) {
            acc += song[i].second
            if (acc > bgmBeat) {
                noteIndex = i
                break
            }
            if (i == song.size - 1) {
                bgmBeat = 0
                noteIndex = 0
                break
            }
        }
        
        val noteName = song[noteIndex].first
        
        var prevAcc = 0
        for (i in 0 until noteIndex) {
            prevAcc += song[i].second
        }
        
        if (bgmBeat == prevAcc && noteName != "rest") {
            val freq = scale[noteName]
            if (freq != null) {
                val duration = song[noteIndex].second * 60.0 / bgmBpm / 4.0
                playGuzhengThreaded(freq, (duration * 0.9).toFloat())
            }
        }
        
        bgmBeat++
    }

    private fun playGuzhengThreaded(frequency: Float, duration: Float, volume: Float = 0.12f) {
        Thread {
            try {
                // Synthesize the PCM data for the guzheng
                val numSamples = (sampleRate * duration).toInt()
                val buffer = ByteBuffer.allocateDirect(numSamples * 2 * 2) // STEREO 16-bit
                buffer.order(ByteOrder.nativeOrder())
                
                var phase1 = 0f
                var phase2 = 0f
                val inc1 = frequency / sampleRate
                val inc2 = (frequency * 2) / sampleRate
                
                for (i in 0 until numSamples) {
                    val t = i.toFloat() / numSamples.toFloat()
                    val attack = Math.min(t * 50f, 1f)
                    val decay = Math.exp(-t * 4.0).toFloat()
                    val env = attack * decay * volume
                    
                    val tri = 4.0f * Math.abs(phase1 - 0.5f) - 1.0f
                    val harm = Math.sin(phase2 * 2.0 * Math.PI).toFloat() * 0.3f
                    val vib = Math.sin(i.toFloat() / sampleRate * 5.0 * 2.0 * Math.PI).toFloat() * 0.003f
                    
                    val sampleFloat = (tri + harm) * env
                    var sampleShort = (sampleFloat * Short.MAX_VALUE).toInt().toShort()
                    
                    // Left and right channel
                    buffer.putShort(sampleShort)
                    buffer.putShort(sampleShort)
                    
                    phase1 += inc1 * (1.0f + vib)
                    phase2 += inc2 * (1.0f + vib)
                    if (phase1 >= 1f) phase1 -= 1f
                    if (phase2 >= 1f) phase2 -= 1f
                }
                
                val track = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build())
                    .setBufferSizeInBytes(numSamples * 2 * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()
                
                buffer.flip()
                val array = ByteArray(buffer.remaining())
                buffer.get(array)
                
                track.write(array, 0, array.size)
                track.play()
                
                // Release after playing
                Thread.sleep((duration * 1000).toLong() + 100)
                track.release()

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }
    
    private fun playToneThreaded(frequency: Float, waveType: String, duration: Float, volume: Float) {
        Thread {
            try {
                val numSamples = (sampleRate * duration).toInt()
                val buffer = ByteBuffer.allocateDirect(numSamples * 2 * 2)
                buffer.order(ByteOrder.nativeOrder())

                var phase = 0f
                val increment = frequency / sampleRate

                for (i in 0 until numSamples) {
                    val t = i.toFloat() / numSamples.toFloat()
                    val envelope = volume * (1.0f - t)

                    val sample = when (waveType) {
                        "square" -> if (phase < 0.5f) 1.0f else -1.0f
                        "sawtooth" -> 2.0f * phase - 1.0f
                        "triangle" -> 4.0f * Math.abs(phase - 0.5f).toFloat() - 1.0f
                        else -> Math.sin(phase * 2.0 * Math.PI).toFloat()
                    }

                    val s = (sample * envelope * Short.MAX_VALUE).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
                    buffer.putShort(s)
                    buffer.putShort(s)

                    phase += increment
                    if (phase >= 1f) phase -= 1f
                }

                val track = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build())
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build())
                    .setBufferSizeInBytes(numSamples * 2 * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                buffer.flip()
                val array = ByteArray(buffer.remaining())
                buffer.get(array)
                track.write(array, 0, array.size)
                track.play()
                Thread.sleep((duration * 1000).toLong() + 50)
                track.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    fun playSFX(type: com.douluo.bridge.ui.SFXType) {
        when (type) {
            com.douluo.bridge.ui.SFXType.JUMP -> playToneThreaded(880f, "sine", 0.07f, 0.10f)
            com.douluo.bridge.ui.SFXType.ATTACK -> playToneThreaded(350f, "sawtooth", 0.05f, 0.09f)
            com.douluo.bridge.ui.SFXType.DASH -> playToneThreaded(200f, "square", 0.10f, 0.12f)
            com.douluo.bridge.ui.SFXType.HIT -> playToneThreaded(300f, "triangle", 0.04f, 0.07f)
            com.douluo.bridge.ui.SFXType.KILL -> playToneThreaded(550f, "sine", 0.12f, 0.14f)
            com.douluo.bridge.ui.SFXType.BOSS_WARNING -> {
                playToneThreaded(110f, "square", 0.4f, 0.20f)
                handler.postDelayed({ playToneThreaded(82f, "square", 0.6f, 0.22f) }, 500)
            }
            com.douluo.bridge.ui.SFXType.BOSS_DEATH -> {
                playToneThreaded(440f, "sine", 0.15f, 0.18f)
                handler.postDelayed({ playToneThreaded(660f, "sine", 0.15f, 0.16f) }, 150)
                handler.postDelayed({ playToneThreaded(880f, "sine", 0.3f, 0.20f) }, 300)
            }
            com.douluo.bridge.ui.SFXType.DROP_THROUGH -> playToneThreaded(440f, "sine", 0.05f, 0.06f)
            com.douluo.bridge.ui.SFXType.SKILL_FIRE -> playToneThreaded(500f, "sawtooth", 0.10f, 0.11f)
            com.douluo.bridge.ui.SFXType.SKILL_WHIRLWIND -> playToneThreaded(400f, "sine", 0.12f, 0.09f)
            com.douluo.bridge.ui.SFXType.SKILL_SHIELD -> playToneThreaded(180f, "triangle", 0.10f, 0.11f)
            com.douluo.bridge.ui.SFXType.SKILL_LIGHTNING -> playToneThreaded(900f, "square", 0.06f, 0.11f)
            com.douluo.bridge.ui.SFXType.SKILL_GHOST -> playToneThreaded(150f, "sine", 0.15f, 0.09f)
            com.douluo.bridge.ui.SFXType.UI_CLICK -> playToneThreaded(600f, "sine", 0.025f, 0.05f)
        }
    }

    private var savedSongId = 0
    private var savedBpm = 100f

    fun startBossBGM() {
        savedSongId = bgmSongId
        savedBpm = bgmBpm
        startBGM(10, 160f)
    }

    fun restoreLevelBGM() {
        startBGM(savedSongId, savedBpm)
    }

    fun release() {
        stopBGM()
    }
}
