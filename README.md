FPGA I2C Interface for SHT30 Sensor (DE1 Cyclone II)
📌 Project Objective

This project implements a custom I2C Master in Verilog to interface the Sensirion SHT30-DIS temperature and humidity sensor with the Altera DE1 Cyclone II FPGA board.

The design performs:

I2C start/stop generation

Sensor command transmission

Multi-byte data read

Temperature & humidity display on 7-segment

🧰 Hardware Used

DE1 Cyclone II FPGA (EP2C20F484C7)

Sensirion SHT30-DIS Sensor

4.7kΩ Pull-up resistors (SDA, SCL)

3.3V supply

🏗 Project Architecture

Top Module
│
├── sht3x_i2c_master.v (I2C Master Core)
├── sht3x_de1_top.v (System Integration)
├── bin2bcd_8bit.v (Binary to BCD Conversion)
└── seg7_decoder.v (7-Segment Display Driver)

🔄 I2C Transaction Flow

START condition

Send slave address (0x44)

Send measurement command (0x2400)

Wait for measurement completion

Repeated START

Read 6 bytes (Temp + CRC + Hum + CRC)

STOP condition

📂 Folder Structure

rtl/ → Synthesizable Verilog modules
tb/ → Testbench files
constraints/ → DE1 pin assignments
docs/ → Block diagrams and connection diagrams
sim/ → Simulation waveforms

🚀 Future Improvements

CRC-8 validation implementation

UART data transmission

Periodic measurement mode

Multi-sensor expansion

📊 Status

✔ RTL Implemented
✔ Top-Level Integrated
⬜ CRC Validation
⬜ Hardware Validation
