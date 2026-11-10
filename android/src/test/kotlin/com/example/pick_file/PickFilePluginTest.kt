package com.example.pick_file

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.assertThrows
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

internal class PickFilePluginTest {

    @Test
    fun pluginInstantiation_succeeds() {
        val plugin = PickFilePlugin()
        assertNotNull(plugin)
    }

    @Test
    fun pickFiles_whenActivityNull_throwsPlatformUnavailable() {
        val plugin = PickFilePlugin()
        val options = FilePickOptionsDto(
            allowMultiple = false,
            filterType = "any"
        )

        val exception = assertThrows<FlutterError> {
            runBlocking {
                plugin.pickFiles(options)
            }
        }

        assertEquals("platform_unavailable", exception.code)
    }
}
