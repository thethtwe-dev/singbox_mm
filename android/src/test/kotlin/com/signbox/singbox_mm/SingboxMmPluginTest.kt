package com.signbox.singbox_mm

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito

internal class SingboxMmPluginTest {
    @Test
    fun onMethodCall_getState_returnsDisconnectedByDefault() {
        val plugin = SingboxMmPlugin()

        val call = MethodCall("getState", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success("disconnected")
    }
}
