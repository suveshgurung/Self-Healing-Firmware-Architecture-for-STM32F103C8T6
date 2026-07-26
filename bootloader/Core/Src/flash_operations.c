/*
 * flash_operations.c
 *
 *  Created on: Jul 16, 2026
 *      Author: subbu
 */

#include "main.h"
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "flash_operations.h"
#include "flash_layout.h"
#include "app_header.h"

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

void flash_program(uint32_t address, uint16_t data) {
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
		*(__IO uint16_t *)address = data;

		status_reg = FLASH->SR;
		while (status_reg & 0x0001) {
			status_reg = FLASH->SR;
		}
	}
}

void erase_application_pages(void) {
	const app_header_t *app_header = (const app_header_t *) APP_HEADER_START_ADDR;
	uint32_t app_size = app_header->app_size;
	uint8_t number_of_pages = (uint8_t)ceil(app_size / 1024.0);
	for (uint8_t i = 0; i < number_of_pages; i++) {
	  flash_erase(APP_START_ADDR + (i * 1024));
	}

	/* Check every erased address */
	char message[100];
	uint32_t *application_start_addr = (uint32_t *) APP_START_ADDR;
	uint32_t number_of_words = ceil(app_size / 4.0);
	do {
	  uint32_t value_at_address = *(application_start_addr + number_of_words);
	  if (value_at_address != 0xFFFFFFFF) {
		  sprintf(message, "Error erasing application memory: %p\r\n", (application_start_addr + number_of_words));
		  HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
	  }
	  number_of_words--;
	}	while(number_of_words != 0);
	sprintf(message, "Application memory erase operation completed!!!\r\n");
	HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
}

void write_application_into_flash(void) {
	const app_header_t *app_header = (const app_header_t *) APP_HEADER_START_ADDR;
	const uint32_t *app_bkp_start_addr = (const uint32_t *) APP_BKP_START_ADDR;
	uint32_t app_size = app_header->app_size;
	uint32_t number_of_words = (uint32_t)ceil(app_size / 4.0);

	uint32_t bkp_data;
	uint16_t upper_half;
	uint16_t lower_half;
	for (uint32_t i = 0; i < number_of_words; i++) {
		bkp_data = *(app_bkp_start_addr + i);
		upper_half = (bkp_data >> 16);
		lower_half = (bkp_data >> 0);

		flash_program(APP_START_ADDR + (i * 4), lower_half);
		flash_program(APP_START_ADDR + (i * 4) + 2, upper_half);
	}

	char message[100];
	sprintf(message, "Application rewritten to flash\r\n");
	HAL_UART_Transmit(&huart1, (uint8_t *)message, strlen(message), HAL_MAX_DELAY);
}
