/*
 * flash_operations.c
 *
 *  Created on: Jul 16, 2026
 *      Author: subbu
 */

#include "main.h"
#include "flash_operations.h"
#include <string.h>
#include <stdio.h>

extern UART_HandleTypeDef huart1;

void flash_unlock(void) {
	FLASH->KEYR = KEY_1;
	FLASH->KEYR = KEY_2;
}

void flash_erase(uint32_t start_address) {
	uint32_t status_reg = FLASH->SR;

	/* BSY bit in SR is set. Wait till it is reset. */
	while (status_reg & 0x0001) {
		status_reg = FLASH->SR;
	}

	char message[100];
	uint32_t control_reg = FLASH->CR;
	uint8_t flash_unlocked = 1;

	/* Flash is locked. Perform the flash unlock sequence. */
	if ((control_reg & 0x0080) != 0) {
		flash_unlocked = 0;
		sprintf(message, "Flash locked\r\nUnlocking...\r\n");
		HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
		flash_unlock();
		control_reg = FLASH->CR;
		if ((control_reg & 0x0080) == 0) {
		  flash_unlocked = 1;
		  sprintf(message, "Flash unlocked!\r\n");
		  HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
		}
	}

	if (flash_unlocked) {
		/* Set PER bit in CR register. */
		FLASH->CR = control_reg | (1 << 1);
		/* Write address within the page to be deleted */
		FLASH->AR = start_address;
		/* Set STRT bit to start the page erase operation */
		FLASH->CR |= (1 << 6);

		/* Wait till the erase operation in completed */
		status_reg = FLASH->SR;
		while (status_reg & 0x0001) {
			status_reg = FLASH->SR;
		}
	}
}

void flash_program(void) {
	uint32_t status_reg = FLASH->SR;

	/* BSY bit in SR is set. Wait till it is reset. */
	while (status_reg & 0x0001) {
		status_reg = FLASH->SR;
	}

	char message[100];
	uint32_t control_reg = FLASH->CR;
	uint8_t flash_unlocked = 1;

	/* Flash is locked. Perform the flash unlock sequence. */
	if ((control_reg & 0x0080) != 0) {
		flash_unlocked = 0;
		sprintf(message, "Flash locked\r\nUnlocking...\r\n");
		HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
		flash_unlock();
		control_reg = FLASH->CR;
		if ((control_reg & 0x0080) == 0) {
		  flash_unlocked = 1;
		  sprintf(message, "Flash unlocked!\r\n");
		  HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
		}
	}

	if (flash_unlocked) {
		/* Set PG bit in CR register. */
		FLASH->CR = control_reg | (1 << 0);
		FLASH->AR = 0x08004400;
	}
}
