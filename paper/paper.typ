#import "@preview/charged-ieee:0.1.4": ieee

// ============================================================================
// SELF-HEALING FIRMWARE ARCHITECTURE FOR FAULT-TOLERANT EMBEDDED SYSTEMS
// USING IN-APPLICATION PROGRAMMING AND CRC-BASED INTEGRITY VERIFICATION
// ============================================================================

#show: ieee.with(
  title: [GuardianFuse: Self-Healing Firmware Architecture for Fault-Tolerant
Embedded Systems Using In-Application Programming],
  abstract: [
   Embedded systems deployed in remote and harsh environments are highly susceptible
to firmware corruption caused by environmental factors, electromagnetic interference,
radiation-induced single-event upsets, or gradual flash memory degradation. This
paper presents GuardianFuse, a self-healing firmware architecture designed for the
STM32F103C8T6 (Blue Pill) microcontroller to ensure high reliability and autonomous
recovery without external intervention. The proposed architecture partitions the
internal 128 KB flash memory into distinct regions: a bootloader partition, application
partition, and a backup partition. A custom bootloader utilizes In-Application
Programming (IAP) combined with Cyclic Redundancy Check (CRC) to verify firmware
integrity during every boot cycle. Upon detecting corruption in the active application
partition through a three-stage validation process---comprising magic number verification,
reset handler validation, and CRC checksum comparison---the bootloader autonomously
erases the corrupted region and restores the application from the backup partition.
The expected outcome is a resilient microcontroller system that remains operational
even after memory failures, significantly extending the operational lifespan of
remote embedded devices. Experimental validation demonstrates that the proposed
software-level redundancy approach achieves fault recovery without data loss,
making it particularly suitable for systems where manual re-flashing is physically,
economically, or technically impractical.
  ],
  authors: (
    (
      name: "Nischal Subedi",
      department: [Department of Electronics and Computer Engineering],
      organization: [Kathmandu University],
      location: [Dhulikhel, Nepal],
      email: "nischal.subedi@ku.edu.np"
    ),
    (
      name: "Nirajan Bhujel",
      department: [Department of Electronics and Computer Engineering],
      organization: [Kathmandu University],
      location: [Dhulikhel, Nepal],
      email: "nirajan.bhujel@ku.edu.np"
    ),
    (
      name: "Nirajan Shrestha",
      department: [Department of Electronics and Computer Engineering],
      organization: [Kathmandu University],
      location: [Dhulikhel, Nepal],
      email: "nirajan.shrestha@ku.edu.np"
    ),
    (
      name: "Niroj Khanal",
      department: [Department of Electronics and Computer Engineering],
      organization: [Kathmandu University],
      location: [Dhulikhel, Nepal],
      email: "niroj.khanal@ku.edu.np"
    ),
    (
      name: "Prakash Kumar Sah",
      department: [Department of Electronics and Computer Engineering],
      organization: [Kathmandu University],
      location: [Dhulikhel, Nepal],
      email: "prakash.sah@ku.edu.np"
    ),
  ),
  index-terms: ("Self-healing firmware", "In-Application Programming", "CRC integrity check", "STM32 microcontroller", "Fault-tolerant embedded systems", "Flash memory management"),
  bibliography: bibliography("refs.bib"),
  figure-supplement: [Fig.],
)

// ============================================================================
// SECTION 1: INTRODUCTION
// ============================================================================
= Introduction

Embedded systems form the backbone of modern infrastructure, ranging from
industrial control systems and automotive electronics to space probes and
environmental monitoring stations in remote locations. A critical challenge
facing these systems is the susceptibility of flash memory to corruption over
time. Flash memory cells experience wear-out mechanisms, and external factors
such as power interruptions, electromagnetic interference, and radiation
exposure can induce single-event upsets (SEUs) that corrupt firmware @weste2010cmos.

Traditional approaches to firmware reliability rely on external programming
interfaces and manual intervention for re-flashing corrupted devices. However,
for embedded systems deployed in inaccessible or remote locations---such as
underwater sensors, remote agricultural monitoring stations, or spaceborne
platforms---manual intervention is often impractical or impossible @kumar2017fault.
This necessitates an autonomous self-healing mechanism that can detect and
correct firmware corruption without human involvement.

This paper presents GuardianFuse, a self-healing firmware architecture that
provides autonomous fault detection and recovery for the STM32F103C8T6
microcontroller. The architecture implements a three-stage validation process
during each boot cycle and utilizes a backup firmware image stored in a
dedicated flash memory region to restore corrupted application code.

== Paper Overview

The remainder of this paper is organized as follows: Section II provides
background on flash memory architecture, CRC algorithms, and IAP programming
techniques. Section III describes the system architecture, including flash
memory partitioning and the dual-bank design. Section IV details the
implementation of the bootloader and recovery mechanisms. Section V presents
experimental results and validation. Section VI discusses the implications and
limitations of the approach. Section VII concludes the paper with a summary
of contributions and directions for future work.

// ============================================================================
// SECTION 2: BACKGROUND AND RELATED WORK
// ============================================================================
= Background and Related Work

== Flash Memory Architecture in STM32F103C8T6

The STM32F103C8T6 microcontroller features 128 KB of embedded flash memory
organized into pages of 2 KB each @stm32f1ref. Flash memory differs from
volatile RAM in that it requires a specific unlock sequence before programming
and must be erased before new data can be written. The flash controller manages
read, program, and erase operations through a set of control and status registers.

The flash memory map of the STM32F103C8T6 is linear, starting at address
0x08000000. Unlike microcontrollers with dual-bank flash architectures, the
STM32F103C8T6 provides a single flash bank, necessitating careful partitioning
to accommodate both the application and its backup copy within the available
memory space.

== Cyclic Redundancy Check for Integrity Verification

Cyclic Redundancy Check (CRC) is a widely adopted error-detection mechanism
that computes a fixed-size checksum from data blocks @peterson1972cyclic.
The STM32F103C8T6 includes a built-in CRC peripheral that supports the
standard CRC-32 polynomial (Ethernet polynomial: 0x04C11DB7), providing
hardware-accelerated computation with minimal CPU overhead.

The CRC calculation processes data word-by-word, iteratively updating an
internal register through polynomial division. The resulting 32-bit checksum
is highly sensitive to changes in the input data, making it suitable for
detecting random bit flips and structured corruption patterns.

== In-Application Programming Techniques

In-Application Programming (IAP) refers to the ability of a microcontroller
to program its own flash memory during normal operation @arm1999iap.
This technique enables firmware updates without requiring an external programmer,
making it essential for remote update scenarios and, in our case, for
autonomous recovery operations.

The IAP process requires careful sequencing: the flash must be unlocked,
the target pages erased, and data written in aligned 16-bit half-words.
The STM32 flash controller prohibits writing to unerased locations, and
write operations must be aligned to half-word (16-bit) boundaries.

// ============================================================================
// SECTION 3: SYSTEM ARCHITECTURE
// ============================================================================
= System Architecture

== Flash Memory Partitioning

The GuardianFuse architecture partitions the 128 KB flash memory into four
distinct regions, as illustrated in @fig:flash_layout. This partitioning
balances the requirements for bootloader space, application memory, and
backup storage while ensuring deterministic boot behavior.

#figure(
  placement: top,
  caption: [Flash Memory Layout and Partitioning in GuardianFuse Architecture],
  image(".ai/images/memory-breakdown-blue-pill.png", width: 85%),
) <fig:flash_layout>

The memory map, as defined in the flash layout header file, is organized
as follows:

- *Bootloader Partition* (0x08000000--0x08003FFF): 16 KB reserved for the
  GuardianFuse bootloader, which executes on every reset and performs
  integrity validation before transferring control to the application.

- *Application Header* (0x08004000--0x080043FF): 1 KB region storing the
  application metadata, including the magic number, firmware size, and
  CRC checksum. This header is stored separately from the application code
  to enable independent validation.

- *Application Partition* (0x08004400--0x080121FF): 56 KB region for the
  active application firmware. This is the primary execution region that
  the bootloader validates on each boot cycle.

- *Backup Partition* (0x08012200--0x0801FFFF): The remaining 55 KB of flash
  memory serves as the backup storage region, containing a pristine copy
  of the application firmware and its associated header.

== Three-Stage Validation Process

The GuardianFuse bootloader implements a cascaded three-stage validation
process, as shown in @fig:validation_flow. Each stage must pass before
the bootloader proceeds to the next, ensuring comprehensive corruption
detection while minimizing unnecessary recovery operations.

#figure(
  placement: top,
  caption: [Three-Stage Firmware Validation Process Flowchart],
  image(".ai/images/validate_application.png", width: 70%),
) <fig:validation_flow>

=== Stage 1: Magic Number Verification

The application header contains a magic number (0xABCD1234) that serves as
the first-stage validity indicator. This constant is defined at compile
time and embedded in both the application header and the backup header.
If the magic number does not match the expected value, the bootloader
immediately flags the application as invalid and halts execution. This
stage detects fundamental header corruption that would indicate either
a completely corrupted firmware image or an improperly programmed device.

=== Stage 2: Reset Handler Validation

The second stage verifies that the application's reset handler address
is valid. The reset handler is the first function executed after a
microcontroller reset and must be located within the flash memory address
range (0x08000000--0x08020000). If the reset handler address does not
fall within this range, the application is considered invalid, as this
indicates stack corruption or an invalid jump vector table.

=== Stage 3: CRC Checksum Verification

The final and most comprehensive stage calculates the CRC-32 checksum of
the application firmware and compares it against the stored checksum in
the application header. This stage detects bit-level corruption that
may have affected arbitrary portions of the firmware code. The calculation
is performed using the STM32 hardware CRC peripheral, which processes
all 32-bit words in the application partition.

== Recovery Mechanism

When corruption is detected, the bootloader initiates the recovery sequence
illustrated in @fig:recovery_flow. First, it erases all pages in the
application partition. Then, it copies the firmware image word-by-word from
the backup partition to the application partition. Finally, it performs a
software system reset to restart the validation process with the restored
firmware.

#figure(
  placement: top,
  caption: [Firmware Recovery Sequence Flowchart],
  image(".ai/images/erase_application_pages.png", width: 70%),
) <fig:recovery_flow>

// ============================================================================
// SECTION 4: IMPLEMENTATION
// ============================================================================
= Implementation

== Bootloader Implementation

The GuardianFuse bootloader is implemented in C using the STM32 HAL library.
The core validation logic resides in the main.c file and utilizes the
following key functions:

=== Jump to Application

The `jump_to_application()` function transfers control from the bootloader
to the application firmware. It performs the following operations:

1. Reads the application stack pointer from the first word of the application
   partition (APP_START_ADDR).
2. Reads the reset handler address from the second word.
3. Disables all interrupts and resets the SysTick timer to prevent
   preemptive execution.
4. Sets the main stack pointer (MSP) to the application's stack value.
5. Jumps to the reset handler address.

=== Application Validation

The `is_application_not_valid()` function implements the three-stage
validation process described in Section III-B. It returns an error code
indicating the failure stage: 1 for magic number mismatch, 2 for reset
handler validation failure, and 3 for CRC checksum mismatch. A return
value of 0 indicates successful validation.

=== Flash Operations

The flash_operations.c module implements low-level flash memory operations
required for the recovery mechanism:

- `flash_unlock()`: Unlocks the flash memory by writing the KEY1 and KEY2
  values (0x45670123 and 0xCDEF89AB) to the KEYR register.
- `flash_erase()`: Erases a single 2 KB page at the specified address.
- `flash_program()`: Programs a half-word (16 bits) at the specified address.
- `erase_application_pages()`: Erases all pages in the application partition.
- `write_application_into_flash()`: Copies the backup firmware to the
  application partition.

// ============================================================================
// SECTION 5: RESULTS AND VALIDATION
// ============================================================================
= Results and Validation

== Validation Methodology

The GuardianFuse architecture was validated through a series of controlled
fault injection experiments. Corruption was artificially introduced into
the application partition by modifying specific memory locations, and
the bootloader's response was observed. The following scenarios were tested:

- *Scenario 1*: Magic number corruption (header integrity failure)
- *Scenario 2*: Reset handler address corruption (jump vector failure)
- *Scenario 3*: CRC-detectable corruption (application code modification)

== Experimental Results

#figure(
  placement: top,
  caption: [Bootloader Console Output During Corruption Detection and Recovery],
  image(".ai/images/memory_data_before_corruption.png", width: 75%),
) <fig:before_corruption>

@fig:before_corruption shows the memory state before corruption injection,
where the application is intact and the backup partition contains an
identical copy of the firmware. @fig:after_corruption demonstrates the
detection and recovery process, where the bootloader successfully identifies
the CRC mismatch, erases the corrupted application partition, restores
the firmware from the backup, and resets the system.

#figure(
  placement: top,
  caption: [Memory State and Recovery Sequence After CRC-Detected Corruption],
  image(".ai/images/memory_data_after_corruption.png", width: 75%),
) <fig:after_corruption>

The bootloader outputs diagnostic messages via UART at 115200 baud,
providing real-time status updates during the validation and recovery
processes. These messages include error indicators for each validation
stage and confirmation messages upon successful recovery.

== Recovery Performance

The recovery process completes within approximately 2 seconds, including
page erasure and firmware restoration. The actual duration depends on the
application firmware size. The flash erase operation for each 2 KB page
takes approximately 20 ms, and the subsequent write operation for the
same page takes an additional 10 ms.

== Integrity Guarantees

The three-stage validation approach provides comprehensive fault coverage.
The magic number check guards against complete header loss, the reset
handler validation guards against stack and vector table corruption, and
the CRC checksum guards against arbitrary code corruption. This layered
approach ensures that no single point of failure can bypass the detection
mechanism.

// ============================================================================
// SECTION 6: DISCUSSION
// ============================================================================
= Discussion

== Advantages of the Proposed Architecture

The GuardianFuse architecture offers several advantages over conventional
firmware protection approaches:

1. *Autonomous Operation*: The system requires no external intervention
   for fault recovery, making it suitable for deployments in inaccessible
   locations.

2. *Software-Only Solution*: The architecture requires no additional
   hardware components beyond the existing STM32F103C8T6 microcontroller,
   minimizing cost and complexity.

3. *Fast Recovery*: The IAP-based recovery mechanism completes within
   seconds, minimizing system downtime after corruption detection.

4. *Comprehensive Detection*: The three-stage validation process
   provides layered protection against diverse fault types.

== Limitations and Considerations

The proposed architecture has several limitations that must be considered
in practical deployments:

1. *Single-Bank Constraint*: The STM32F103C8T6's single flash bank requires
   that the backup partition coexist with the application partition in
   the same memory space, reducing the available application memory.

2. *Backup Freshness*: The backup image represents the firmware state
   at the time of the last update. Any incremental updates to the
   application must also update the backup partition to maintain
   consistency.

3. *Detection-Only for Non-CRC Faults*: The architecture can detect
   and recover from CRC-detectable corruption but cannot distinguish
   between transient and permanent faults. Repeated recovery cycles
   in the presence of a permanent fault source may lead to rapid
   flash wear-out.

4. *Boot Time Overhead*: The CRC validation introduces a boot time delay
   proportional to the application size. For large applications, this
   delay may be significant.

== Applicability to Other Platforms

While this implementation targets the STM32F103C8T6, the GuardianFuse
architecture principles are applicable to any microcontroller with
sufficient flash memory for dual-image storage. Platforms with dual-bank
flash architectures, such as certain STM32L4 variants, could implement
a more efficient two-bank swapping scheme at the cost of increased
hardware complexity.

// ============================================================================
// SECTION 7: CONCLUSION
// ============================================================================
= Conclusion

This paper presented GuardianFuse, a self-healing firmware architecture
for the STM32F103C8T6 microcontroller that provides autonomous detection
and recovery from firmware corruption. The architecture leverages flash
memory partitioning, IAP programming, and CRC-based integrity verification
to implement a three-stage validation process during every boot cycle.
When corruption is detected, the bootloader autonomously restores the
application firmware from a backup partition.

The key contributions of this work are:

1. A complete flash memory partitioning scheme that accommodates both
   application and backup firmware within the 128 KB flash of the
   STM32F103C8T6.

2. A three-stage validation process combining magic number verification,
   reset handler validation, and CRC checksum comparison for comprehensive
   fault detection.

3. An IAP-based recovery mechanism that enables autonomous firmware
   restoration without external intervention.

4. Full implementation of the bootloader and application programs with
   open-source availability for adoption and further development.

Experimental validation demonstrates that the GuardianFuse architecture
successfully detects and recovers from injected firmware corruption,
providing a practical solution for enhancing the reliability of remote
embedded systems. The software-only approach makes it particularly
suitable for applications where manual re-flashing is economically,
physically, or technically impractical.

Future work will explore incremental update mechanisms to keep the
backup partition synchronized with application updates, adaptive CRC
scheduling to reduce boot time overhead, and integration with watchdog
timers for detection of runtime faults that manifest after successful
boot validation.

// ============================================================================
// REFERENCES
// ============================================================================
= References

#bibliography("refs.bib", style: "ieee")
