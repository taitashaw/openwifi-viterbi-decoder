/*
 * Real on-hardware test: pushes one actual regression test case (case 1 of
 * the 920-case suite, len=24, from vhdl/stimulus.txt) through the AXI DMA
 * into the Viterbi decoder running on the PL, and checks the decoded bytes
 * that come back against the known-correct golden model output. TX/RX byte
 * packing matches exactly what the AXI-stream testbench (tb_viterbi_axis.vhd)
 * already proved correct in simulation: sym0 in tdata[7:5], sym1 in
 * tdata[4:2], erase in tdata[1:0]; received bytes concatenated LSB-first.
 */
#include "xaxidma.h"
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "sleep.h"

#define TX_BUFFER_BASE 0x02000000
#define RX_BUFFER_BASE 0x02100000

#define TX_LEN 24
#define RX_LEN 3

static const u8 TxData[TX_LEN] = {
    0x50, 0x8c, 0x98, 0x90, 0x3c, 0x14, 0xd0, 0xd4,
    0xe4, 0x50, 0x7c, 0xd4, 0x34, 0x0c, 0x88, 0x00,
    0x28, 0xb4, 0x40, 0x14, 0xb0, 0x04, 0x54, 0xb8
};

static const u8 ExpectedRx[RX_LEN] = { 0x7a, 0xfc, 0x8a };

int main(void)
{
    XAxiDma AxiDma;
    XAxiDma_Config *CfgPtr;
    int Status;
    u8 *TxBufferPtr = (u8 *)TX_BUFFER_BASE;
    u8 *RxBufferPtr = (u8 *)RX_BUFFER_BASE;

    xil_printf("\r\n=== viterbi_k7_axis real hardware test ===\r\n");

    CfgPtr = XAxiDma_LookupConfig((UINTPTR)XPAR_XAXIDMA_0_BASEADDR);
    if (!CfgPtr) {
        xil_printf("RESULT: FAIL (no DMA config found)\r\n");
        return 1;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("RESULT: FAIL (DMA CfgInitialize error %d)\r\n", Status);
        return 1;
    }

    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("RESULT: FAIL (DMA unexpectedly in SG mode)\r\n");
        return 1;
    }

    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    for (int i = 0; i < TX_LEN; i++) {
        TxBufferPtr[i] = TxData[i];
    }
    for (int i = 0; i < RX_LEN; i++) {
        RxBufferPtr[i] = 0xFF;
    }

    Xil_DCacheFlushRange((UINTPTR)TxBufferPtr, TX_LEN);
    Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, RX_LEN);

    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBufferPtr, RX_LEN,
                                     XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        xil_printf("RESULT: FAIL (S2MM SimpleTransfer error %d)\r\n", Status);
        return 1;
    }

    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBufferPtr, TX_LEN,
                                     XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("RESULT: FAIL (MM2S SimpleTransfer error %d)\r\n", Status);
        return 1;
    }

    xil_printf("Transfer started, waiting for completion...\r\n");

    int timeout = 2000000;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE) && timeout-- > 0) {}
    if (timeout <= 0) {
        xil_printf("RESULT: FAIL (MM2S timed out, never completed)\r\n");
        return 1;
    }

    timeout = 2000000;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA) && timeout-- > 0) {}
    if (timeout <= 0) {
        xil_printf("RESULT: FAIL (S2MM timed out, never completed)\r\n");
        return 1;
    }

    Xil_DCacheInvalidateRange((UINTPTR)RxBufferPtr, RX_LEN);

    xil_printf("Received bytes: ");
    for (int i = 0; i < RX_LEN; i++) {
        xil_printf("%02x ", RxBufferPtr[i]);
    }
    xil_printf("\r\n");

    xil_printf("Expected bytes: ");
    for (int i = 0; i < RX_LEN; i++) {
        xil_printf("%02x ", ExpectedRx[i]);
    }
    xil_printf("\r\n");

    int mismatch = 0;
    for (int i = 0; i < RX_LEN; i++) {
        if (RxBufferPtr[i] != ExpectedRx[i]) {
            mismatch = 1;
        }
    }

    if (mismatch) {
        xil_printf("RESULT: FAIL (decoded bytes do not match golden model)\r\n");
    } else {
        xil_printf("RESULT: PASS (real hardware decode matches golden model)\r\n");
    }

    return 0;
}
