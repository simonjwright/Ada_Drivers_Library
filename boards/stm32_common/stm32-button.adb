------------------------------------------------------------------------------
--                                                                          --
--                 Copyright (C) 2015-2016, AdaCore                         --
--                                                                          --
--  Redistribution and use in source and binary forms, with or without      --
--  modification, are permitted provided that the following conditions are  --
--  met:                                                                    --
--     1. Redistributions of source code must retain the above copyright    --
--        notice, this list of conditions and the following disclaimer.     --
--     2. Redistributions in binary form must reproduce the above copyright --
--        notice, this list of conditions and the following disclaimer in   --
--        the documentation and/or other materials provided with the        --
--        distribution.                                                     --
--     3. Neither the name of STMicroelectronics nor the names of its       --
--        contributors may be used to endorse or promote products derived   --
--        from this software without specific prior written permission.     --
--                                                                          --
--   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    --
--   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      --
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  --
--   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   --
--   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, --
--   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       --
--   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  --
--   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  --
--   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    --
--   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  --
--   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Real_Time; use Ada.Real_Time;

with STM32.Board;   use STM32.Board;
with STM32.Device;  use STM32.Device;
with STM32.GPIO;    use STM32.GPIO;
with STM32.EXTI;    use STM32.EXTI;

package body STM32.Button is

   Button_High   : constant Boolean := True;
   Debounce_Time : constant Time_Span := Milliseconds (250);
   Initialized   : Boolean := False;

   protected Button_Prot is
      pragma Interrupt_Priority;

      function Get_State return Boolean;
      procedure Clear_State;

   private
      procedure Interrupt;
      pragma Attach_Handler (Interrupt, User_Button_Interrupt);

      Pressed    : Boolean := False;
      Start_Time : Time    := Clock;
   end Button_Prot;

   -----------------
   -- Button_Prot --
   -----------------

   protected body Button_Prot
   is
      ---------------
      -- Interrupt --
      ---------------

      procedure Interrupt
      is
      begin
         Clear_External_Interrupt
           (User_Button_Point.Get_Interrupt_Line_Number);

         if (Button_High and then User_Button_Point.Set)
           or else (not Button_High and then not User_Button_Point.Set)
         then
            if Clock - Start_Time > Debounce_Time then
               Pressed := True;
            end if;
         end if;
      end Interrupt;

      ---------------
      -- Get_State --
      ---------------

      function Get_State return Boolean is
      begin
         return Pressed;
      end Get_State;

      -----------------
      -- Clear_State --
      -----------------

      procedure Clear_State is
      begin
         if Pressed then
            Start_Time := Clock;
            Pressed := False;
         end if;
      end Clear_State;

   end Button_Prot;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
   is
   begin
      if Initialized then
         return;
      end if;

      Initialized := True;
      Enable_Clock (User_Button_Point);

      User_Button_Point.Configure_IO
        ((Mode        => Mode_In,
          Output_Type => Open_Drain,
          Speed       => Speed_50MHz,
          Resistors   => (if Button_High then Pull_Down else Pull_Up)));

      --  We connect the button's pin the the External Interrupt Handler
      User_Button_Point.Configure_Trigger
        ((if Button_High then Interrupt_Rising_Edge
          else Interrupt_Falling_Edge));
   end Initialize;

   ----------------------
   -- Has_Been_Pressed --
   ----------------------

   function Has_Been_Pressed return Boolean
   is
      State : Boolean;
   begin
      if not Initialized then
         Initialize;
      end if;

      State := Button_Prot.Get_State;
      Button_Prot.Clear_State;

      return State;
   end Has_Been_Pressed;

end STM32.Button;