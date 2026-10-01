package com.draskint.qabal

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.draskint.qabal.ui.theme.DesignShowcase
import com.draskint.qabal.ui.theme.QabalTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Temporal: el muestrario del sistema de diseño hasta que exista la navegación.
        setContent { QabalTheme { DesignShowcase() } }
    }
}
