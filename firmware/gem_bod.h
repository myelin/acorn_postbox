/*
    Source: https://github.com/wntrblm/Castor_and_Pollux/blob/main/firmware/src/hw/gem_bod.h

    Copyright (c) 2021 Alethea Katherine Flowers.
    Published under the standard MIT License.
    Full text available at: https://opensource.org/licenses/MIT
*/

#pragma once

/* Routines for interacting with the SAM D21's brown out detector (BOD33) */

void gem_wait_for_stable_voltage();
