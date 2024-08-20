from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim, vmodl
import time
import ssl


class VMToolsExecuter:
  vms = None

  def __init__(self, vc_server: str, vc_username: str, vc_password: str):
      self.server = vc_server
      self.username = vc_username
      self.password = vc_password

      # Disable SSL warnings and establish connection
      sslContext = ssl._create_unverified_context()
      self.si = SmartConnect(host=self.server,
                        user=self.username,
                        pwd=self.password,
                        sslContext=sslContext)

      self.content = self.si.RetrieveContent()

  def get_vms(self, realod=False):
      if (self.vms == None) or (realod == False):
          self.vms = []

          container = self.content.rootFolder  # starting point to look into
          view_type = [vim.VirtualMachine]  # object types to look for
          recursive = True  # whether we should look into it recursively

          container_view = self.content.viewManager.CreateContainerView(
              container, view_type, recursive
          )
          children = container_view.view
          for child in children:
              self.vms.append(child)

      return self.vms

  def disconnect(self):
      Disconnect(self.si)
      return self

  def load_guest_credentials(self, username: str, password: str):
      self.guest_username = username
      self.guest_password = password

      return self

  def script_on_vm(
          self,
          vm_name: str,
          script: str,
          wait=True,
          throw_error: bool = True,
          username: str = None,
          password: str = None,
          timeout: int = 3600,
          platform: str = 'auto'
  ):

      # Validate platform type
      valid_platforms = ['windows', 'linux', 'auto']
      if platform not in valid_platforms:
          raise Exception(f"Platform type ({platform}) is not valid, please select: {valid_platforms}")

      # Validate credentials is existed
      if (username != None) and (password != None):
          guest_username = username
          guest_password = password

      elif (self.guest_username != None) and (self.guest_password != None):
          guest_username = self.guest_username
          guest_password = self.guest_password

      elif throw_error:
          raise Exception(
              "Please supply guest credentials either with `load_guest_credentials` method or as username & password arguments!")
      else:
          return None

      vm = None

      # Validate VM object is existed!
      for curr_vmn in self.get_vms():
          if vm_name.lower().strip() in curr_vmn.name.lower().strip():
              vm = curr_vmn
              break

      if vm == None and throw_error:
          raise Exception(f"Virtual machine named {vm_name} is not existed!")

      # Check platform type?
      platform_by_vmtools =  vm.guest.guestFullName.lower()
      if platform == 'auto':
          if 'linux' in platform_by_vmtools:
              platform = 'linux'
          elif 'windows' in platform_by_vmtools:
              platform = 'windows'
          else:
              raise Exception(f"Failed to get machine ({vm_name}) OS platform, result was: {platform_by_vmtools}")

      # Check if VMware Tools is running
      if vm.guest.toolsRunningStatus != 'guestToolsRunning':
          if throw_error:
            raise Exception(f"VMware Tools is not running on the {vm_name} VM")
          else:
              return None

      # Create a ProgramSpec object
      if platform == 'windows':
          program_spec = vim.vm.guest.ProcessManager.ProgramSpec()
          program_spec.programPath = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
          program_spec.arguments = f'-Command "{script}"'
      else:
          # Create a ProgramSpec object
          program_spec = vim.vm.guest.ProcessManager.ProgramSpec()
          program_spec.programPath = "/bin/bash"
          program_spec.arguments = f"-c '{script}'"

      # Get the guest credentials
      guest_auth = vim.vm.guest.NamePasswordAuthentication(
          username=guest_username,
          password=guest_password
      )

      # Get the Process Manager
      pm = self.content.guestOperationsManager.processManager

      # Start the process on the guest OS
      data = {
              "status": None,
              "message": "",
              "vm": vm_name,
              "guest_username": guest_username,
              "wait": wait
        }

      try:
          data['pid'] = pm.StartProgramInGuest(vm, guest_auth, program_spec)

      except vmodl.MethodFault as error:
          data['status'] = False
          data['message'] = error.msg


      if wait == False or data['status'] == False:
        return data

      # Wait for the process to complete and retrieve the output
      process_ended = False
      time_out_counter = 0

      while not process_ended:
          time.sleep(1)  # Wait for 2 seconds before checking the status
          processes = pm.ListProcessesInGuest(vm, guest_auth, [data['pid']])
          for proc in processes:
              if proc.exitCode is not None:  # Process has finished
                  process_ended = True
                  data['status_code']  = proc.exitCode
                  break

          if process_ended:
              break
          elif time_out_counter < timeout:
              print(f"Process {data['pid']} is on vm {vm_name} still running...")
              time_out_counter += 1
          else:
              data['status'] = False
              data['message'] = f"Timeout of ({timeout}) is reached out!"

              return data


      # Check the exit code and output
      if process_ended:
          # You can capture the output via a script to a file and read the file here if necessary
          if proc.exitCode == 0:
              data['status'] = True
              print(f"Process completed successfully with output: {proc.exitCode}")
          else:
              data['status'] = False
              print(f"Process failed with exit code: {proc.exitCode}")

      return data



if __name__ == "__main__":
    #  Install the Required Python Packages
    # pip install pyvmomi pywinrm

    # Variables
    server = "10.0.0.1"
    username = "administrator@vsphere.local"
    password = "password"

    # vm
    vm = "pc1"
    guest_username = "danielmandelblat"
    guest_password = "danielmandelblatpassword"

    session = VMToolsExecuter(server, username, password)

    res = session.script_on_vm(vm, username=guest_username, password=guest_password, script='hostname', platform='windows') # platform = ['auto', 'windows', 'linux']

    print(res)
  
    session.disconnect()
