//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------------------------
module uvm.comps.uvm_random_stimulus;
import uvm.base.uvm_component;
import uvm.base.uvm_transaction;
import uvm.base.uvm_object_defines;

//------------------------------------------------------------------------------
// CLASS: uvm_random_stimulus #(T)
//
// A general purpose unidirectional random stimulus class.
//
// The uvm_random_stimulus class generates streams of T transactions. These streams
// may be generated by the randomize method of T, or the randomize method of
// one of its subclasses.  The stream may go indefinitely, until terminated
// by a call to stop_stimulus_generation, or we may specify the maximum number
// of transactions to be generated.
//
// By using inheritance, we can add directed initialization or tidy up after
// random stimulus generation. Simply extend the class and define the run task,
// calling super.run() when you want to begin the random stimulus phase of
// simulation.
//
// While very useful in its own right, this component can also be used as a
// template for defining other stimulus generators, or it can be extended to
// add additional stimulus generation methods and to simplify test writing.
//
//------------------------------------------------------------------------------

class uvm_random_stimulus(T=uvm_transaction): uvm_component
{
  enum string type_name = "uvm_random_stimulus!(T)";

  alias uvm_random_stimulus!T this_type;

  mixin uvm_component_utils;

  // Port: blocking_put_port
  //
  // The blocking_put_port is used to send the generated stimulus to the rest
  // of the testbench.

  uvm_blocking_put_port!T blocking_put_port;


  // Function: new
  //
  // Creates a new instance of a specialization of this class.
  // Also, displays the random state obtained from a get_randstate call.
  // In subsequent simulations, set_randstate can be called with the same
  // value to reproduce the same sequence of transactions.

  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      blocking_put_port=new uvm_blocking_put_port("blocking_put_port", this);
      uvm_report_info("uvm_stimulus", "rand state is " ~ get_randstate());
    }
  }


  private bool _m_stop;
  private bool m_stop() {synchronized(this) return _m_stop;}


  // Function: generate_stimulus
  //
  // Generate up to max_count transactions of type T.
  // If t is not specified, a default instance of T is allocated and used.
  // If t is specified, that transaction is used when randomizing. It must
  // be a subclass of T.
  //
  // max_count is the maximum number of transactions to be
  // generated. A value of zero indicates no maximum - in
  // this case, generate_stimulus will go on indefinitely
  // unless stopped by some other process
  //
  // The transactions are cloned before they are sent out
  // over the blocking_put_port

  // task
  void generate_stimulus(T t=null, int max_count=0) {

    if (t is null) t = new T;
    for (size_t i=0; (max_count is 0 || i < max_count) && ! m_stop; ++i) {

      if (! t.randomize() ) {
	uvm_report_warning ("RANDFL", "Randomization failed in generate_stimulus");
      }

      T temp = cast(T) t.clone();
      uvm_report_info("stimulus generation", temp.to!string());
      blocking_put_port.put(temp);
    }
  }


  // Function: stop_stimulus_generation
  //
  // Stops the generation of stimulus.
  // If a subclass of this method has forked additional
  // processes, those processes will also need to be
  // stopped in an overridden version of this method

  void stop_stimulus_generation() {
    synchronized(this) {
      _m_stop = 1;
    }
  }


  string get_type_name() {
    return type_name;
  }

}
